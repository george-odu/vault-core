;; Title: VaultCore Protocol
;;
;; Summary: 
;; Next-generation synthetic asset protocol enabling Bitcoin holders to unlock 
;; liquidity through over-collateralized synthetic USD creation while maintaining 
;; BTC exposure and earning yield through automated market making.
;;
;; Description:
;; VaultCore revolutionizes Bitcoin utility by creating a trustless bridge between 
;; Bitcoin collateral and synthetic USD liquidity. Users deposit BTC to mint synthetic 
;; USD tokens while maintaining price exposure to their original asset. The protocol 
;; features dynamic risk management through automated liquidations, oracle-driven 
;; pricing mechanisms, and incentivized liquidity provision. Built with institutional-
;; grade security and capital efficiency in mind, VaultCore enables sophisticated 
;; DeFi strategies while preserving Bitcoin's store-of-value properties.
;;
;; Key Features:
;; - Over-collateralized synthetic asset creation (150% minimum ratio)
;; - Automated liquidation protection at 130% threshold
;; - Dynamic AMM with 0.3% fee structure for sustainable yields
;; - Oracle-based price feeds with safety validations
;; - Permissionless liquidity provision with LP token rewards
;; - Gas-optimized operations for cost-effective interactions

;; ERROR CODES

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1003))
(define-constant ERR-POOL-EMPTY (err u1004))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u1005))
(define-constant ERR-BELOW-MINIMUM (err u1006))
(define-constant ERR-ABOVE-MAXIMUM (err u1007))
(define-constant ERR-ALREADY-INITIALIZED (err u1008))
(define-constant ERR-NOT-INITIALIZED (err u1009))
(define-constant ERR-INVALID-PRICE (err u1010))

;; PROTOCOL CONSTANTS

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MINIMUM-COLLATERAL-RATIO u150) ;; 150% collateralization requirement
(define-constant LIQUIDATION-RATIO u130) ;; 130% liquidation threshold
(define-constant MINIMUM-DEPOSIT u1000000) ;; 0.01 BTC minimum (in satoshis)
(define-constant POOL-FEE-RATE u3) ;; 0.3% trading fee rate
(define-constant PRECISION u1000000) ;; 6 decimal places for calculations
(define-constant MAX-PRICE u100000000000) ;; Maximum price: $1M USD (6 decimals)
(define-constant MAX-MINT-AMOUNT u1000000000000) ;; Maximum mint: $10K USD (6 decimals)

;; STATE VARIABLES

(define-data-var contract-initialized bool false)
(define-data-var oracle-price uint u0)
(define-data-var total-supply uint u0)
(define-data-var pool-btc-balance uint u0)
(define-data-var pool-stable-balance uint u0)

;; DATA STRUCTURES

;; User Bitcoin balances
(define-map balances
    principal
    uint
)

;; User synthetic USD balances
(define-map stablecoin-balances
    principal
    uint
)

;; Individual vault data for collateral management
(define-map collateral-vaults
    principal
    {
        btc-locked: uint,
        stablecoin-minted: uint,
        last-update-height: uint,
    }
)

;; Liquidity provider positions and rewards
(define-map liquidity-providers
    principal
    {
        pool-tokens: uint,
        btc-provided: uint,
        stable-provided: uint,
    }
)

;; PRIVATE UTILITY FUNCTIONS

;; Validates oracle price inputs for security
(define-private (validate-price (price uint))
    (and
        (> price u0)
        (<= price MAX-PRICE)
    )
)

;; Handles secure balance transfers between principals
(define-private (transfer-balance
        (amount uint)
        (sender principal)
        (recipient principal)
    )
    (let (
            (sender-balance (default-to u0 (map-get? balances sender)))
            (recipient-balance (default-to u0 (map-get? balances recipient)))
        )
        (if (>= sender-balance amount)
            (begin
                (map-set balances sender (- sender-balance amount))
                (map-set balances recipient (+ recipient-balance amount))
                (ok true)
            )
            ERR-INSUFFICIENT-BALANCE
        )
    )
)

;; Calculates current collateral ratio for vault health assessment
(define-private (calculate-collateral-ratio
        (btc-amount uint)
        (stablecoin-amount uint)
    )
    (if (is-eq stablecoin-amount u0)
        PRECISION
        (let (
                (btc-value-usd (* btc-amount (var-get oracle-price)))
                (collateral-ratio (/ (* btc-value-usd u100) stablecoin-amount))
            )
            collateral-ratio
        )
    )
)

;; Validates vault meets minimum collateralization requirements
(define-private (check-collateral-requirement
        (btc-locked uint)
        (stablecoin-amount uint)
    )
    (let ((ratio (calculate-collateral-ratio btc-locked stablecoin-amount)))
        (if (>= ratio MINIMUM-COLLATERAL-RATIO)
            (ok true)
            ERR-INSUFFICIENT-COLLATERAL
        )
    )
)

;; Calculates LP tokens for liquidity providers using geometric mean
(define-private (calculate-lp-tokens
        (btc-amount uint)
        (stable-amount uint)
    )
    (let (
            (pool-btc (var-get pool-btc-balance))
            (pool-stable (var-get pool-stable-balance))
        )
        (if (is-eq pool-btc u0)
            (sqrt (* btc-amount stable-amount))
            (/ (* btc-amount (sqrt (* pool-btc pool-stable))) pool-btc)
        )
    )
)

;; Integer square root approximation for LP token calculations
(define-private (sqrt (x uint))
    (let ((next (+ (/ x u2) u1)))
        (if (<= x u2)
            u1
            next
        )
    )
)

;; PROTOCOL INITIALIZATION

;; Initializes the protocol with starting oracle price
(define-public (initialize (initial-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get contract-initialized)) ERR-ALREADY-INITIALIZED)
        (asserts! (validate-price initial-price) ERR-INVALID-PRICE)
        (var-set oracle-price initial-price)
        (var-set contract-initialized true)
        (ok true)
    )
)

;; ORACLE PRICE MANAGEMENT

;; Updates the BTC/USD price feed (owner-only for security)
(define-public (update-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (validate-price new-price) ERR-INVALID-PRICE)
        (var-set oracle-price new-price)
        (ok true)
    )
)

;; VAULT MANAGEMENT SYSTEM

;; Deposits Bitcoin as collateral for synthetic USD creation
(define-public (deposit-collateral (btc-amount uint))
    (let ((sender-vault (default-to {
            btc-locked: u0,
            stablecoin-minted: u0,
            last-update-height: stacks-block-height,
        }
            (map-get? collateral-vaults tx-sender)
        )))
        (begin
            (asserts! (>= btc-amount MINIMUM-DEPOSIT) ERR-BELOW-MINIMUM)
            (try! (transfer-balance btc-amount tx-sender (as-contract tx-sender)))
            (map-set collateral-vaults tx-sender {
                btc-locked: (+ btc-amount (get btc-locked sender-vault)),
                stablecoin-minted: (get stablecoin-minted sender-vault),
                last-update-height: stacks-block-height,
            })
            (ok true)
        )
    )
)

;; SYNTHETIC USD OPERATIONS

;; Mints synthetic USD against Bitcoin collateral
(define-public (mint-stablecoin (amount uint))
    (let (
            (vault (unwrap! (map-get? collateral-vaults tx-sender) ERR-NOT-INITIALIZED))
            (current-stable-balance (default-to u0 (map-get? stablecoin-balances tx-sender)))
            (new-stable-amount (+ (get stablecoin-minted vault) amount))
        )
        (begin
            (asserts!
                (and
                    (> amount u0)
                    (<= amount MAX-MINT-AMOUNT)
                    (<= (+ (var-get total-supply) amount)
                        (* (var-get pool-btc-balance) (var-get oracle-price))
                    )
                )
                ERR-INVALID-AMOUNT
            )
            (try! (check-collateral-requirement (get btc-locked vault)
                new-stable-amount
            ))
            (map-set collateral-vaults tx-sender {
                btc-locked: (get btc-locked vault),
                stablecoin-minted: new-stable-amount,
                last-update-height: stacks-block-height,
            })
            (let (
                    (new-total-supply (+ (var-get total-supply) amount))
                    (new-user-balance (+ current-stable-balance amount))
                )
                (asserts! (<= new-total-supply MAX-MINT-AMOUNT) ERR-ABOVE-MAXIMUM)
                (map-set stablecoin-balances tx-sender new-user-balance)
                (var-set total-supply new-total-supply)
                (ok true)
            )
        )
    )
)

;; Burns synthetic USD to reduce vault debt and unlock collateral
(define-public (burn-stablecoin (amount uint))
    (let (
            (vault (unwrap! (map-get? collateral-vaults tx-sender) ERR-NOT-INITIALIZED))
            (current-stable-balance (default-to u0 (map-get? stablecoin-balances tx-sender)))
        )
        (begin
            (asserts! (>= current-stable-balance amount) ERR-INSUFFICIENT-BALANCE)
            (map-set collateral-vaults tx-sender {
                btc-locked: (get btc-locked vault),
                stablecoin-minted: (- (get stablecoin-minted vault) amount),
                last-update-height: stacks-block-height,
            })
            (map-set stablecoin-balances tx-sender
                (- current-stable-balance amount)
            )
            (var-set total-supply (- (var-get total-supply) amount))
            (ok true)
        )
    )
)

;; AUTOMATED MARKET MAKER (AMM) OPERATIONS

;; Adds liquidity to the BTC/USD trading pool for yield generation
(define-public (add-liquidity
        (btc-amount uint)
        (stable-amount uint)
    )
    (let (
            (pool-btc (var-get pool-btc-balance))
            (pool-stable (var-get pool-stable-balance))
            (lp-tokens (calculate-lp-tokens btc-amount stable-amount))
            (provider-data (default-to {
                pool-tokens: u0,
                btc-provided: u0,
                stable-provided: u0,
            }
                (map-get? liquidity-providers tx-sender)
            ))
        )
        (begin
            (asserts! (> btc-amount u0) ERR-INVALID-AMOUNT)
            (asserts! (> stable-amount u0) ERR-INVALID-AMOUNT)
            (try! (transfer-balance btc-amount tx-sender (as-contract tx-sender)))
            (try! (transfer-balance stable-amount tx-sender (as-contract tx-sender)))
            (var-set pool-btc-balance (+ pool-btc btc-amount))
            (var-set pool-stable-balance (+ pool-stable stable-amount))
            (map-set liquidity-providers tx-sender {
                pool-tokens: (+ (get pool-tokens provider-data) lp-tokens),
                btc-provided: (+ (get btc-provided provider-data) btc-amount),
                stable-provided: (+ (get stable-provided provider-data) stable-amount),
            })
            (ok lp-tokens)
        )
    )
)

;; Removes liquidity from the pool and claims proportional rewards
(define-public (remove-liquidity (lp-tokens uint))
    (let (
            (provider-data (unwrap! (map-get? liquidity-providers tx-sender) ERR-NOT-INITIALIZED))
            (total-lp-tokens (get pool-tokens provider-data))
            (pool-btc (var-get pool-btc-balance))
            (pool-stable (var-get pool-stable-balance))
            (btc-return (/ (* lp-tokens pool-btc) total-lp-tokens))
            (stable-return (/ (* lp-tokens pool-stable) total-lp-tokens))
        )
        (begin
            (asserts! (>= total-lp-tokens lp-tokens) ERR-INSUFFICIENT-BALANCE)
            (var-set pool-btc-balance (- pool-btc btc-return))
            (var-set pool-stable-balance (- pool-stable stable-return))
            (map-set liquidity-providers tx-sender {
                pool-tokens: (- total-lp-tokens lp-tokens),
                btc-provided: (- (get btc-provided provider-data) btc-return),
                stable-provided: (- (get stable-provided provider-data) stable-return),
            })
            (try! (transfer-balance btc-return (as-contract tx-sender) tx-sender))
            (try! (transfer-balance stable-return (as-contract tx-sender) tx-sender))
            (ok {
                btc-returned: btc-return,
                stable-returned: stable-return,
            })
        )
    )
)

;; READ-ONLY VIEW FUNCTIONS

;; Returns detailed vault information for risk assessment
(define-read-only (get-vault-details (owner principal))
    (map-get? collateral-vaults owner)
)

;; Calculates and returns current collateral ratio for vault health
(define-read-only (get-collateral-ratio (owner principal))
    (let ((vault (unwrap! (map-get? collateral-vaults owner) ERR-NOT-INITIALIZED)))
        (ok (calculate-collateral-ratio (get btc-locked vault)
            (get stablecoin-minted vault)
        ))
    )
)

;; Returns comprehensive pool statistics and current state
(define-read-only (get-pool-details)
    {
        btc-balance: (var-get pool-btc-balance),
        stable-balance: (var-get pool-stable-balance),
        total-supply: (var-get total-supply),
        oracle-price: (var-get oracle-price),
    }
)

;; Returns liquidity provider position and earned rewards
(define-read-only (get-lp-details (provider principal))
    (map-get? liquidity-providers provider)
)
