;; InnovatePay Research Funding Contract with Reputation System
;; Milestone-based research funding with on-chain reputation tracking

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROJECT_NOT_FOUND (err u101))
(define-constant ERR_MILESTONE_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_COMPLETED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_INVALID_MILESTONE (err u105))
(define-constant ERR_PROJECT_ALREADY_EXISTS (err u106))

;; Data Variables
(define-data-var project-counter uint u0)

;; Data Maps
(define-map projects
  { project-id: uint }
  {
    researcher: principal,
    funder: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    total-funding: uint,
    released-funding: uint,
    milestone-count: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    funding-amount: uint,
    is-completed: bool,
    completed-at: (optional uint),
    reviewer: (optional principal)
  }
)

(define-map researcher-reputation
  { researcher: principal }
  {
    total-projects: uint,
    completed-projects: uint,
    total-milestones: uint,
    completed-milestones: uint,
    reputation-score: uint,
    last-updated: uint
  }
)

(define-map funder-reputation
  { funder: principal }
  {
    total-funded-projects: uint,
    total-funded-amount: uint,
    reputation-score: uint,
    last-updated: uint
  }
)

;; Private Functions

(define-private (calculate-researcher-reputation (total-projects uint) (completed-projects uint) (total-milestones uint) (completed-milestones uint))
  (let
    (
      (project-completion-rate (if (> total-projects u0) (/ (* completed-projects u100) total-projects) u0))
      (milestone-completion-rate (if (> total-milestones u0) (/ (* completed-milestones u100) total-milestones) u0))
      (base-score (+ project-completion-rate milestone-completion-rate))
    )
    (if (> base-score u100) u100 base-score)
  )
)

(define-private (update-researcher-reputation (researcher principal) (milestone-completed bool))
  (let
    (
      (current-rep (default-to 
        { total-projects: u0, completed-projects: u0, total-milestones: u0, completed-milestones: u0, reputation-score: u0, last-updated: u0 }
        (map-get? researcher-reputation { researcher: researcher })
      ))
      (new-total-milestones (+ (get total-milestones current-rep) u1))
      (new-completed-milestones (if milestone-completed (+ (get completed-milestones current-rep) u1) (get completed-milestones current-rep)))
      (new-reputation-score (calculate-researcher-reputation 
        (get total-projects current-rep)
        (get completed-projects current-rep)
        new-total-milestones
        new-completed-milestones
      ))
    )
    (map-set researcher-reputation
      { researcher: researcher }
      {
        total-projects: (get total-projects current-rep),
        completed-projects: (get completed-projects current-rep),
        total-milestones: new-total-milestones,
        completed-milestones: new-completed-milestones,
        reputation-score: new-reputation-score,
        last-updated: stacks-block-height
      }
    )
  )
)

;; Update researcher project count (when project is created)
(define-private (update-researcher-project-count (researcher principal))
  (let
    (
      (current-rep (default-to 
        { total-projects: u0, completed-projects: u0, total-milestones: u0, completed-milestones: u0, reputation-score: u0, last-updated: u0 }
        (map-get? researcher-reputation { researcher: researcher })
      ))
      (new-total-projects (+ (get total-projects current-rep) u1))
      (new-reputation-score (calculate-researcher-reputation 
        new-total-projects
        (get completed-projects current-rep)
        (get total-milestones current-rep)
        (get completed-milestones current-rep)
      ))
    )
    (map-set researcher-reputation
      { researcher: researcher }
      (merge current-rep {
        total-projects: new-total-projects,
        reputation-score: new-reputation-score,
        last-updated: stacks-block-height
      })
    )
  )
)

;; Update funder reputation
(define-private (update-funder-reputation (funder principal) (amount uint))
  (let
    (
      (current-rep (default-to 
        { total-funded-projects: u0, total-funded-amount: u0, reputation-score: u50, last-updated: u0 }
        (map-get? funder-reputation { funder: funder })
      ))
      (new-total-projects (+ (get total-funded-projects current-rep) u1))
      (new-total-amount (+ (get total-funded-amount current-rep) amount))
      (calculated-score (+ u50 (/ new-total-projects u2)))
      (new-reputation-score (if (> calculated-score u100) u100 calculated-score))
    )
    (map-set funder-reputation
      { funder: funder }
      {
        total-funded-projects: new-total-projects,
        total-funded-amount: new-total-amount,
        reputation-score: new-reputation-score,
        last-updated: stacks-block-height
      }
    )
  )
)

;; Public Functions

;; Create a new research project
(define-public (create-project 
  (researcher principal)
  (title (string-ascii 100))
  (description (string-ascii 500))
  (milestone-count uint)
  (total-funding uint)
)
  (let
    (
      (new-project-id (+ (var-get project-counter) u1))
    )
    (asserts! (> milestone-count u0) ERR_INVALID_MILESTONE)
    (asserts! (<= milestone-count u10) ERR_INVALID_MILESTONE)
    (asserts! (> total-funding u0) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? total-funding tx-sender (as-contract tx-sender)))
    
    ;; Create project
    (map-set projects
      { project-id: new-project-id }
      {
        researcher: researcher,
        funder: tx-sender,
        title: title,
        description: description,
        total-funding: total-funding,
        released-funding: u0,
        milestone-count: milestone-count,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    
    ;; Update funder reputation
    (update-funder-reputation tx-sender total-funding)
    
    ;; Update researcher reputation (new project)
    (update-researcher-project-count researcher)
    
    (var-set project-counter new-project-id)
    (ok new-project-id)
  )
)

;; Add milestone to existing project
(define-public (add-milestone 
  (project-id uint)
  (milestone-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (funding-amount uint)
)
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
    )
    ;; Only funder can add milestones
    (asserts! (is-eq tx-sender (get funder project)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active project) ERR_NOT_AUTHORIZED)
    (asserts! (< milestone-id (get milestone-count project)) ERR_INVALID_MILESTONE)
    (asserts! (is-none (map-get? milestones { project-id: project-id, milestone-id: milestone-id })) ERR_ALREADY_COMPLETED)
    
    ;; Create milestone
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        title: title,
        description: description,
        funding-amount: funding-amount,
        is-completed: false,
        completed-at: none,
        reviewer: none
      }
    )
    
    (ok true)
  )
)

;; Complete a milestone and release funds
(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
      (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
    )
    ;; Only funder can complete milestones
    (asserts! (is-eq tx-sender (get funder project)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active project) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-completed milestone)) ERR_ALREADY_COMPLETED)
    
    ;; Mark milestone as completed
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone {
        is-completed: true,
        completed-at: (some stacks-block-height),
        reviewer: (some tx-sender)
      })
    )
    
    ;; Release funds to researcher
    (try! (as-contract (stx-transfer? (get funding-amount milestone) tx-sender (get researcher project))))
    
    ;; Update project released funding
    (map-set projects
      { project-id: project-id }
      (merge project {
        released-funding: (+ (get released-funding project) (get funding-amount milestone))
      })
    )
    
    ;; Update researcher reputation
    (update-researcher-reputation (get researcher project) true)
    
    (ok true)
  )
)

;; Mark project as completed (when all milestones are done)
(define-public (complete-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get funder project)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active project) ERR_NOT_AUTHORIZED)
    
    ;; Mark project as inactive (completed)
    (map-set projects
      { project-id: project-id }
      (merge project { is-active: false })
    )
    
    ;; Update researcher reputation (completed project)
    (let
      (
        (current-rep (unwrap-panic (map-get? researcher-reputation { researcher: (get researcher project) })))
        (new-completed-projects (+ (get completed-projects current-rep) u1))
        (new-reputation-score (calculate-researcher-reputation 
          (get total-projects current-rep)
          new-completed-projects
          (get total-milestones current-rep)
          (get completed-milestones current-rep)
        ))
      )
      (map-set researcher-reputation
        { researcher: (get researcher project) }
        (merge current-rep {
          completed-projects: new-completed-projects,
          reputation-score: new-reputation-score,
          last-updated: stacks-block-height
        })
      )
    )
    
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-researcher-reputation (researcher principal))
  (map-get? researcher-reputation { researcher: researcher })
)

(define-read-only (get-funder-reputation (funder principal))
  (map-get? funder-reputation { funder: funder })
)

(define-read-only (get-project-count)
  (var-get project-counter)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)