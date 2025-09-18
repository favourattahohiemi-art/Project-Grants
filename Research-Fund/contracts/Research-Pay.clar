;; Research Funding Smart Contract
;; A comprehensive contract for managing research proposals, funding, milestones, and payments

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-proposal-exists (err u105))
(define-constant err-invalid-status (err u106))
(define-constant err-milestone-not-ready (err u107))
(define-constant err-already-voted (err u108))
(define-constant err-voting-closed (err u109))
(define-constant err-invalid-milestone (err u110))
(define-constant err-proposal-not-active (err u111))
(define-constant err-milestone-already-completed (err u112))
(define-constant err-invalid-input (err u113))

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var milestone-counter uint u0)
(define-data-var min-voting-period uint u144) ;; ~1 day in blocks
(define-data-var quorum-percentage uint u51) ;; 51% quorum required

;; Proposal Status Enum
;; 0: Submitted, 1: Under Review, 2: Approved, 3: Active, 4: Completed, 5: Rejected, 6: Cancelled

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    researcher: principal,
    title: (string-utf8 256),
    description: (string-utf8 1024),
    funding-amount: uint,
    duration-blocks: uint,
    status: uint,
    created-at: uint,
    approved-at: (optional uint),
    total-milestones: uint,
    completed-milestones: uint,
    funds-released: uint,
    reviewer: (optional principal)
  }
)

(define-map milestones
  { milestone-id: uint }
  {
    proposal-id: uint,
    title: (string-utf8 256),
    description: (string-utf8 512),
    funding-percentage: uint,
    deadline-block: uint,
    status: uint, ;; 0: Pending, 1: Submitted, 2: Approved, 3: Rejected
    submitted-at: (optional uint),
    evidence-hash: (optional (buff 32))
  }
)

(define-map proposal-milestones
  { proposal-id: uint, milestone-index: uint }
  { milestone-id: uint }
)

(define-map researchers
  { researcher: principal }
  {
    total-proposals: uint,
    active-proposals: uint,
    completed-proposals: uint,
    total-funding-received: uint,
    reputation-score: uint
  }
)

(define-map reviewers
  { reviewer: principal }
  { authorized: bool }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

(define-map proposal-votes
  { proposal-id: uint }
  { 
    yes-votes: uint,
    no-votes: uint,
    voting-ends: uint,
    total-voters: uint
  }
)

(define-map funding-pool
  { pool-id: uint }
  { balance: uint }
)

;; Initialize funding pool
(map-set funding-pool { pool-id: u0 } { balance: u0 })

;; Input validation functions
(define-private (is-valid-principal (principal-input principal))
  (not (is-eq principal-input 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-string (str (string-utf8 1024)))
  (and (> (len str) u0) (<= (len str) u1024))
)

(define-private (is-valid-title (title (string-utf8 256)))
  (and (> (len title) u0) (<= (len title) u256))
)

(define-private (is-valid-description (desc (string-utf8 512)))
  (and (> (len desc) u0) (<= (len desc) u512))
)

(define-private (is-valid-proposal-id (proposal-id uint))
  (and (> proposal-id u0) (<= proposal-id (var-get proposal-counter)))
)

(define-private (is-valid-milestone-id (milestone-id uint))
  (and (> milestone-id u0) (<= milestone-id (var-get milestone-counter)))
)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (if (is-valid-proposal-id proposal-id)
    (map-get? proposals { proposal-id: proposal-id })
    none
  )
)

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
  (if (is-valid-milestone-id milestone-id)
    (map-get? milestones { milestone-id: milestone-id })
    none
  )
)

;; Get researcher profile
(define-read-only (get-researcher (researcher principal))
  (if (is-valid-principal researcher)
    (map-get? researchers { researcher: researcher })
    none
  )
)

;; Check if user is authorized reviewer
(define-read-only (is-authorized-reviewer (reviewer principal))
  (if (is-valid-principal reviewer)
    (default-to false (get authorized (map-get? reviewers { reviewer: reviewer })))
    false
  )
)

;; Get proposal vote count
(define-read-only (get-vote-count (proposal-id uint))
  (if (is-valid-proposal-id proposal-id)
    (map-get? proposal-votes { proposal-id: proposal-id })
    none
  )
)

;; Get user's vote for a proposal
(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (if (and (is-valid-proposal-id proposal-id) (is-valid-principal voter))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
    none
  )
)

;; Get funding pool balance
(define-read-only (get-funding-pool-balance)
  (default-to u0 (get balance (map-get? funding-pool { pool-id: u0 })))
)

;; Get current proposal counter
(define-read-only (get-proposal-counter)
  (var-get proposal-counter)
)

;; Get milestone for proposal by index
(define-read-only (get-proposal-milestone (proposal-id uint) (milestone-index uint))
  (if (is-valid-proposal-id proposal-id)
    (match (map-get? proposal-milestones { proposal-id: proposal-id, milestone-index: milestone-index })
      milestone-data (map-get? milestones { milestone-id: (get milestone-id milestone-data) })
      none
    )
    none
  )
)

;; Administrative functions

;; Add funds to the funding pool (only owner)
(define-public (add-funding (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    
    (let ((current-balance (get-funding-pool-balance)))
      (map-set funding-pool 
        { pool-id: u0 } 
        { balance: (+ current-balance amount) }
      )
      (ok amount)
    )
  )
)

;; Authorize a reviewer (only owner)
(define-public (authorize-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-valid-principal reviewer) err-invalid-input)
    (map-set reviewers { reviewer: reviewer } { authorized: true })
    (ok true)
  )
)

;; Revoke reviewer authorization (only owner)
(define-public (revoke-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-valid-principal reviewer) err-invalid-input)
    (map-set reviewers { reviewer: reviewer } { authorized: false })
    (ok true)
  )
)

;; Update contract parameters (only owner)
(define-public (update-min-voting-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= blocks u10) err-invalid-amount)
    (var-set min-voting-period blocks)
    (ok blocks)
  )
)

(define-public (update-quorum-percentage (percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= percentage u1) (<= percentage u100)) err-invalid-amount)
    (var-set quorum-percentage percentage)
    (ok percentage)
  )
)

;; Helper function to sum a list of numbers
(define-private (sum-list (numbers (list 10 uint)))
  (fold + numbers u0)
)

;; Core proposal functions

;; Submit a research proposal with up to 10 milestones
(define-public (submit-proposal 
  (title (string-utf8 256))
  (description (string-utf8 1024))
  (funding-amount uint)
  (duration-blocks uint)
  (milestone-titles (list 10 (string-utf8 256)))
  (milestone-descriptions (list 10 (string-utf8 512)))
  (milestone-percentages (list 10 uint))
  (milestone-deadlines (list 10 uint))
)
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (current-block stacks-block-height)
    (num-milestones (len milestone-titles))
  )
    ;; Input validation
    (asserts! (is-valid-title title) err-invalid-input)
    (asserts! (is-valid-string description) err-invalid-input)
    (asserts! (> funding-amount u0) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-amount)
    (asserts! (is-eq (len milestone-titles) (len milestone-percentages)) err-invalid-milestone)
    (asserts! (is-eq (len milestone-titles) (len milestone-descriptions)) err-invalid-milestone)
    (asserts! (is-eq (len milestone-titles) (len milestone-deadlines)) err-invalid-milestone)
    (asserts! (<= num-milestones u10) err-invalid-milestone)
    (asserts! (> num-milestones u0) err-invalid-milestone)
    
    ;; Validate milestone percentages sum to 100
    (asserts! (is-eq (sum-list milestone-percentages) u100) err-invalid-milestone)
    
    ;; Validate all milestone data before creating anything
    (asserts! (validate-milestone-data milestone-titles milestone-descriptions milestone-percentages milestone-deadlines) err-invalid-input)
    
    ;; Create proposal
    (map-set proposals 
      { proposal-id: proposal-id }
      {
        researcher: tx-sender,
        title: title,
        description: description,
        funding-amount: funding-amount,
        duration-blocks: duration-blocks,
        status: u0, ;; Submitted
        created-at: current-block,
        approved-at: none,
        total-milestones: num-milestones,
        completed-milestones: u0,
        funds-released: u0,
        reviewer: none
      }
    )
    
    ;; Create milestones using simple approach
    (create-milestones proposal-id milestone-titles milestone-descriptions milestone-percentages milestone-deadlines)
    
    ;; Update researcher profile
    (update-researcher-profile tx-sender proposal-id true)
    
    ;; Update counter
    (var-set proposal-counter proposal-id)
    
    (ok proposal-id)
  )
)

;; Helper function to validate milestone data
(define-private (validate-milestone-data
  (titles (list 10 (string-utf8 256)))
  (descriptions (list 10 (string-utf8 512)))
  (percentages (list 10 uint))
  (deadlines (list 10 uint))
)
  (and
    (validate-milestone-at-index titles descriptions percentages deadlines u0)
    (validate-milestone-at-index titles descriptions percentages deadlines u1)
    (validate-milestone-at-index titles descriptions percentages deadlines u2)
    (validate-milestone-at-index titles descriptions percentages deadlines u3)
    (validate-milestone-at-index titles descriptions percentages deadlines u4)
    (validate-milestone-at-index titles descriptions percentages deadlines u5)
    (validate-milestone-at-index titles descriptions percentages deadlines u6)
    (validate-milestone-at-index titles descriptions percentages deadlines u7)
    (validate-milestone-at-index titles descriptions percentages deadlines u8)
    (validate-milestone-at-index titles descriptions percentages deadlines u9)
  )
)

;; Helper function to validate milestone at specific index
(define-private (validate-milestone-at-index
  (titles (list 10 (string-utf8 256)))
  (descriptions (list 10 (string-utf8 512)))
  (percentages (list 10 uint))
  (deadlines (list 10 uint))
  (index uint)
)
  (if (< index (len titles))
    (let (
      (title (unwrap-panic (element-at titles index)))
      (description (unwrap-panic (element-at descriptions index)))
      (percentage (unwrap-panic (element-at percentages index)))
      (deadline (unwrap-panic (element-at deadlines index)))
    )
      (and
        (is-valid-title title)
        (is-valid-description description)
        (and (> percentage u0) (<= percentage u100))
        (> deadline u0)
      )
    )
    true
  )
)

;; Helper function to create milestones using simple sequential approach
(define-private (create-milestones 
  (proposal-id uint)
  (titles (list 10 (string-utf8 256)))
  (descriptions (list 10 (string-utf8 512)))
  (percentages (list 10 uint))
  (deadlines (list 10 uint))
)
  (begin
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u0)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u1)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u2)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u3)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u4)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u5)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u6)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u7)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u8)
    (create-milestone-if-exists proposal-id titles descriptions percentages deadlines u9)
    true
  )
)

;; Helper function to create milestone if index exists
(define-private (create-milestone-if-exists
  (proposal-id uint)
  (titles (list 10 (string-utf8 256)))
  (descriptions (list 10 (string-utf8 512)))
  (percentages (list 10 uint))
  (deadlines (list 10 uint))
  (index uint)
)
  (if (< index (len titles))
    (let (
      (milestone-id (+ (var-get milestone-counter) u1))
      (current-block stacks-block-height)
      (title (unwrap-panic (element-at titles index)))
      (description (unwrap-panic (element-at descriptions index)))
      (percentage (unwrap-panic (element-at percentages index)))
      (deadline (unwrap-panic (element-at deadlines index)))
    )
      (map-set milestones
        { milestone-id: milestone-id }
        {
          proposal-id: proposal-id,
          title: title,
          description: description,
          funding-percentage: percentage,
          deadline-block: (+ current-block deadline),
          status: u0, ;; Pending
          submitted-at: none,
          evidence-hash: none
        }
      )
      
      (map-set proposal-milestones
        { proposal-id: proposal-id, milestone-index: index }
        { milestone-id: milestone-id }
      )
      
      (var-set milestone-counter milestone-id)
      true
    )
    true
  )
)

;; Review proposal (authorized reviewers only)
(define-public (review-proposal (proposal-id uint) (approve bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    (current-block stacks-block-height)
  )
    ;; Input and state validations
    (asserts! (is-valid-proposal-id proposal-id) err-invalid-input)
    (asserts! (is-authorized-reviewer tx-sender) err-unauthorized)
    (asserts! (is-eq (get status proposal) u0) err-invalid-status) ;; Must be submitted
    
    (if approve
      (begin
        ;; Approve proposal
        (map-set proposals 
          { proposal-id: proposal-id }
          (merge proposal { 
            status: u2, ;; Approved
            approved-at: (some current-block),
            reviewer: (some tx-sender)
          })
        )
        
        ;; Start community voting
        (map-set proposal-votes
          { proposal-id: proposal-id }
          {
            yes-votes: u0,
            no-votes: u0,
            voting-ends: (+ current-block (var-get min-voting-period)),
            total-voters: u0
          }
        )
      )
      ;; Reject proposal
      (map-set proposals 
        { proposal-id: proposal-id }
        (merge proposal { 
          status: u5, ;; Rejected
          reviewer: (some tx-sender)
        })
      )
    )
    
    (ok approve)
  )
)

;; Community voting on approved proposals
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    (vote-data (unwrap! (map-get? proposal-votes { proposal-id: proposal-id }) err-not-found))
    (current-block stacks-block-height)
  )
    ;; Input and state validations
    (asserts! (is-valid-proposal-id proposal-id) err-invalid-input)
    (asserts! (is-eq (get status proposal) u2) err-invalid-status) ;; Must be approved
    (asserts! (<= current-block (get voting-ends vote-data)) err-voting-closed)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote, voted-at: current-block }
    )
    
    ;; Update vote count
    (map-set proposal-votes
      { proposal-id: proposal-id }
      (if vote
        (merge vote-data { 
          yes-votes: (+ (get yes-votes vote-data) u1),
          total-voters: (+ (get total-voters vote-data) u1)
        })
        (merge vote-data { 
          no-votes: (+ (get no-votes vote-data) u1),
          total-voters: (+ (get total-voters vote-data) u1)
        })
      )
    )
    
    (ok vote)
  )
)

;; Finalize voting and activate proposal if passed
(define-public (finalize-voting (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    (vote-data (unwrap! (map-get? proposal-votes { proposal-id: proposal-id }) err-not-found))
    (current-block stacks-block-height)
    (total-votes (get total-voters vote-data))
    (yes-votes (get yes-votes vote-data))
    (quorum-met (>= (* total-votes u100) (var-get quorum-percentage)))
    (proposal-passed (and quorum-met (> yes-votes (get no-votes vote-data))))
  )
    ;; Input and state validations
    (asserts! (is-valid-proposal-id proposal-id) err-invalid-input)
    (asserts! (is-eq (get status proposal) u2) err-invalid-status) ;; Must be approved
    (asserts! (>= current-block (get voting-ends vote-data)) err-voting-closed)
    (asserts! (<= (get funding-amount proposal) (get-funding-pool-balance)) err-insufficient-funds)
    
    (if proposal-passed
      (begin
        ;; Activate proposal
        (map-set proposals 
          { proposal-id: proposal-id }
          (merge proposal { status: u3 }) ;; Active
        )
        
        ;; Reserve funds
        (let ((current-balance (get-funding-pool-balance)))
          (map-set funding-pool 
            { pool-id: u0 } 
            { balance: (- current-balance (get funding-amount proposal)) }
          )
        )
        
        (ok true)
      )
      (begin
        ;; Reject proposal
        (map-set proposals 
          { proposal-id: proposal-id }
          (merge proposal { status: u5 }) ;; Rejected
        )
        (ok false)
      )
    )
  )
)

;; Submit milestone completion
(define-public (submit-milestone (milestone-id uint) (evidence-hash (buff 32)))
  (let (
    (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found))
    (proposal (unwrap! (map-get? proposals { proposal-id: (get proposal-id milestone) }) err-not-found))
    (current-block stacks-block-height)
  )
    ;; Input and state validations
    (asserts! (is-valid-milestone-id milestone-id) err-invalid-input)
    (asserts! (> (len evidence-hash) u0) err-invalid-input)
    (asserts! (is-eq tx-sender (get researcher proposal)) err-unauthorized)
    (asserts! (is-eq (get status proposal) u3) err-proposal-not-active) ;; Must be active
    (asserts! (is-eq (get status milestone) u0) err-milestone-already-completed) ;; Must be pending
    
    ;; Update milestone
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone {
        status: u1, ;; Submitted
        submitted-at: (some current-block),
        evidence-hash: (some evidence-hash)
      })
    )
    
    (ok true)
  )
)

;; Approve milestone and release funds (authorized reviewers only)
(define-public (approve-milestone (milestone-id uint))
  (let (
    (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found))
    (proposal (unwrap! (map-get? proposals { proposal-id: (get proposal-id milestone) }) err-not-found))
    (funding-amount (get funding-amount proposal))
    (milestone-percentage (get funding-percentage milestone))
    (release-amount (/ (* funding-amount milestone-percentage) u100))
    (researcher (get researcher proposal))
  )
    ;; Input and state validations
    (asserts! (is-valid-milestone-id milestone-id) err-invalid-input)
    (asserts! (is-authorized-reviewer tx-sender) err-unauthorized)
    (asserts! (is-eq (get status milestone) u1) err-milestone-not-ready) ;; Must be submitted
    
    ;; Update milestone status
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone { status: u2 }) ;; Approved
    )
    
    ;; Update proposal completion count and funds released
    (let (
      (new-completed (+ (get completed-milestones proposal) u1))
      (new-funds-released (+ (get funds-released proposal) release-amount))
      (new-status (if (is-eq new-completed (get total-milestones proposal)) u4 u3)) ;; Complete if all milestones done
    )
      (map-set proposals 
        { proposal-id: (get proposal-id milestone) }
        (merge proposal { 
          completed-milestones: new-completed,
          funds-released: new-funds-released,
          status: new-status
        })
      )
      
      ;; Update researcher profile if proposal completed
      (if (is-eq new-status u4)
        (update-researcher-completion researcher (get proposal-id milestone) new-funds-released)
        true
      )
    )
    
    ;; Transfer funds to researcher
    (try! (stx-transfer? release-amount (as-contract tx-sender) researcher))
    
    (ok release-amount)
  )
)

;; Helper function to update researcher profile
(define-private (update-researcher-profile (researcher principal) (proposal-id uint) (is-new bool))
  (let (
    (current-profile (default-to 
      { total-proposals: u0, active-proposals: u0, completed-proposals: u0, total-funding-received: u0, reputation-score: u100 }
      (map-get? researchers { researcher: researcher })
    ))
  )
    (if is-new
      (map-set researchers 
        { researcher: researcher }
        (merge current-profile {
          total-proposals: (+ (get total-proposals current-profile) u1),
          active-proposals: (+ (get active-proposals current-profile) u1)
        })
      )
      true
    )
  )
)

;; Helper function to get minimum of two numbers
(define-private (min-uint (a uint) (b uint))
  (if (<= a b) a b)
)

;; Helper function to update researcher completion
(define-private (update-researcher-completion (researcher principal) (proposal-id uint) (funding-received uint))
  (let (
    (current-profile (unwrap-panic (map-get? researchers { researcher: researcher })))
    (new-reputation (+ (get reputation-score current-profile) u50))
  )
    (map-set researchers 
      { researcher: researcher }
      (merge current-profile {
        active-proposals: (- (get active-proposals current-profile) u1),
        completed-proposals: (+ (get completed-proposals current-profile) u1),
        total-funding-received: (+ (get total-funding-received current-profile) funding-received),
        reputation-score: (min-uint u1000 new-reputation) ;; Cap reputation at 1000
      })
    )
  )
)

;; Emergency functions

;; Cancel proposal (researcher or owner only)
(define-public (cancel-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
  )
    ;; Input and authorization validations
    (asserts! (is-valid-proposal-id proposal-id) err-invalid-input)
    (asserts! 
      (or 
        (is-eq tx-sender (get researcher proposal))
        (is-eq tx-sender contract-owner)
      ) 
      err-unauthorized
    )
    
    ;; Can only cancel submitted or approved proposals
    (asserts! 
      (or 
        (is-eq (get status proposal) u0) ;; Submitted
        (is-eq (get status proposal) u2)  ;; Approved
      ) 
      err-invalid-status
    )
    
    (map-set proposals 
      { proposal-id: proposal-id }
      (merge proposal { status: u6 }) ;; Cancelled
    )
    
    (ok true)
  )
)

;; Reject milestone (authorized reviewers only)
(define-public (reject-milestone (milestone-id uint))
  (let (
    (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found))
  )
    ;; Input and authorization validations
    (asserts! (is-valid-milestone-id milestone-id) err-invalid-input)
    (asserts! (is-authorized-reviewer tx-sender) err-unauthorized)
    (asserts! (is-eq (get status milestone) u1) err-milestone-not-ready) ;; Must be submitted
    
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone { status: u3 }) ;; Rejected
    )
    
    (ok true)
  )
)