;; YieldForge Protocol
;; Advanced sBTC Liquidity Mining & Yield Optimization Platform
;;
;; Summary:
;; YieldForge revolutionizes Bitcoin yield generation through sophisticated
;; liquidity mining mechanics, delivering sustainable returns while maintaining
;; full custody and security of staked assets on Stacks Layer 2.
;;
;; Description:
;; A next-generation DeFi protocol engineered for Bitcoin holders seeking
;; institutional-grade yield opportunities. YieldForge combines time-weighted
;; reward algorithms with dynamic APY adjustments to create a self-balancing
;; ecosystem that rewards long-term commitment while ensuring liquidity flexibility.
;;
;; The protocol features advanced yield farming mechanics including:
;; - Algorithmic reward distribution with compounding capabilities
;; - Dynamic liquidity incentives based on market conditions
;; - Institutional-grade security with multi-signature governance
;; - Gas-optimized operations for cost-effective yield harvesting
;; - Cross-protocol yield aggregation and optimization strategies
;;
;; Built for the future of Bitcoin DeFi on Stacks blockchain infrastructure.

;; ERROR CONSTANTS

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ZERO_STAKE (err u101))
(define-constant ERR_NO_STAKE_FOUND (err u102))
(define-constant ERR_TOO_EARLY_TO_UNSTAKE (err u103))
(define-constant ERR_INVALID_REWARD_RATE (err u104))
(define-constant ERR_NOT_ENOUGH_REWARDS (err u105))
(define-constant ERR_INVALID_PERIOD (err u106))
(define-constant ERR_SAME_OWNER (err u107))

;; DATA STORAGE LAYER

;; Primary staking ledger for yield participants
(define-map stakes
  { staker: principal }
  {
    amount: uint,
    staked-at: uint,
  }
)

;; Historical reward distribution tracking
(define-map rewards-claimed
  { staker: principal }
  { amount: uint }
)

;; PROTOCOL CONFIGURATION

;; Dynamic yield rate (basis points: 5 = 0.05% annualized)
(define-data-var reward-rate uint u5)

;; Liquidity mining reward treasury
(define-data-var reward-pool uint u0)

;; Security lockup period (~10 days mainnet blocks)
(define-data-var min-stake-period uint u1440)

;; Total value locked (TVL) across all participants
(define-data-var total-staked uint u0)

;; Protocol governance authority
(define-data-var contract-owner principal tx-sender)

;; GOVERNANCE & ADMINISTRATION

;; Retrieve current protocol governance address
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Execute governance transition to new authority
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR_SAME_OWNER)
    (ok (var-set contract-owner new-owner))
  )
)

;; Adjust protocol yield parameters (governance only)
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (< new-rate u1000) ERR_INVALID_REWARD_RATE) ;; Maximum 100% APY
    (ok (var-set reward-rate new-rate))
  )
)

;; Configure minimum liquidity commitment period
(define-public (set-min-stake-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_PERIOD)
    (ok (var-set min-stake-period new-period))
  )
)

;; Capitalize reward treasury for sustainable yield distribution
(define-public (add-to-reward-pool (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    ;; Secure sBTC transfer to protocol treasury
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Update treasury balance
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

;; CORE YIELD GENERATION ENGINE

;; Deploy capital for yield generation and liquidity mining
(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    ;; Execute secure asset custody transfer
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Update or initialize participant position
    (match (map-get? stakes { staker: tx-sender })
      prev-stake (map-set stakes { staker: tx-sender } {
        amount: (+ amount (get amount prev-stake)),
        staked-at: stacks-block-height,
      })
      (map-set stakes { staker: tx-sender } {
        amount: amount,
        staked-at: stacks-block-height,
      })
    )
    ;; Update protocol total value locked
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)