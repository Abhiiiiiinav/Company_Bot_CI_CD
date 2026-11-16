"""
tests/evaluation/test_reranker_benchmark.py
Automated RAG Reranker Evaluation Benchmark against Intertek Employee Handbook.

Evaluates cross-encoder rerankers (e.g. BGE-Reranker-Base) against challenging lexical
and semantic distractors across 10 golden benchmark queries.

Metrics:
- Hit Rate@1 (Golden chunk is Rank #1)
- Hit Rate@3 (Golden chunk is in Top 3)
- Mean Reciprocal Rank (MRR)
- Distractor Suppression (Golden score > every negative distractor score)
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List
import pytest

from app.infrastructure.vector.bge_reranker import BgeReranker

logger = logging.getLogger(__name__)

# ==============================================================================
# GOLDEN BENCHMARK DATASET (Intertek Employee Handbook)
# ==============================================================================

BENCHMARK_DATASET: List[Dict[str, Any]] = [
    {
        "test_id": "TC-01",
        "name": "Post-Accident Drug Testing vs. Return-to-Work Testing",
        "query": "Under what conditions is an employee subjected to a post-accident drug test, and what is its specific trigger compared to return-to-work testing?",
        "target_source": "Section 'Health & Safety - Drug-Free Workplace Policy' (Pages 37, 39)",
        "target_keywords": ["post-accident", "return to work", "illness or injury", "workplace accident"],
        "golden_chunk": {
            "id": "golden_tc01",
            "section": "Health & Safety - Drug-Free Workplace Policy (Pages 37, 39)",
            "text": (
                "Health & Safety - Drug-Free Workplace Policy: A post-accident drug test may be conducted specifically "
                "when an accident occurs in the workplace or on company property, particularly where injury or significant "
                "property damage results. In contrast, a return-to-work drug test is triggered before an employee is permitted "
                "to return to active work following an extended absence due to illness or injury, specifically to verify "
                "whether any controlled substance is present that could increase the risk of workplace injury or recurrence."
            ),
        },
        "distractors": [
            {
                "id": "tc01_distractor_a",
                "label": "Pre-Employment Screening (Page 9)",
                "text": (
                    "Pre-Employment Screening: All offers of employment at Intertek are strictly contingent upon the candidate "
                    "successfully passing a comprehensive pre-employment drug and alcohol screening examination conducted "
                    "prior to the first day of work in accordance with company policy."
                ),
            },
            {
                "id": "tc01_distractor_b",
                "label": "Reasonable Suspicion Testing (Page 39)",
                "text": (
                    "Reasonable Suspicion Testing: Intertek reserves the right to mandate immediate drug or alcohol screening "
                    "when management has reasonable suspicion based on specific observed behavior, slurred speech, erratic physical "
                    "symptoms, or direct evidence of substance use during working hours."
                ),
            },
            {
                "id": "tc01_distractor_c",
                "label": "Workers' Compensation initial reporting (Page 37)",
                "text": (
                    "Workers' Compensation initial reporting: Employees must report any workplace injuries, occupational illnesses, "
                    "or equipment accidents immediately to their direct supervisor within 24 hours to ensure timely medical evaluation "
                    "and workers' compensation claims initiation."
                ),
            },
        ],
    },
    {
        "test_id": "TC-02",
        "name": "Tuition Reimbursement Repayment Tiers",
        "query": "If an employee leaves Intertek 18 months after receiving education reimbursement, what percentage of the expenses must be repaid?",
        "target_source": "Section 'Education, Training & Professional Development - Education Reimbursement Policy' (Page 26)",
        "target_keywords": ["13-24 months", "50%", "repaid", "course completion"],
        "golden_chunk": {
            "id": "golden_tc02",
            "section": "Education Reimbursement Policy - Repayment Schedule (Page 26)",
            "text": (
                "Education Reimbursement Policy - Repayment Schedule: If an employee voluntarily terminates or leaves Intertek "
                "within 13 to 24 months following course completion, the employee must repay 50% of the total reimbursed "
                "education expenses. The repayment amount is deducted from the final paycheck or settled via promissory agreement."
            ),
        },
        "distractors": [
            {
                "id": "tc02_distractor_a",
                "label": "0-12 months repayment tier (75%) (Page 26)",
                "text": (
                    "Education Reimbursement Policy - Repayment Tier 1: If an employee voluntarily separates from the company "
                    "within 0 to 12 months following completion of the approved course, the employee is required to repay 75% of "
                    "the total reimbursed tuition and academic expenses."
                ),
            },
            {
                "id": "tc02_distractor_b",
                "label": "25-36 months repayment tier (25%) (Page 26)",
                "text": (
                    "Education Reimbursement Policy - Repayment Tier 3: If an employee voluntarily terminates between 25 to 36 months "
                    "following course completion, the employee must repay 25% of reimbursed expenses. Employees leaving after 36 months "
                    "have no repayment obligation (0%)."
                ),
            },
            {
                "id": "tc02_distractor_c",
                "label": "Annual reimbursement maximums (Page 26)",
                "text": (
                    "Education Reimbursement Policy - Benefit Ceilings: Full-time regular employees may receive up to an annual maximum "
                    "reimbursement of $8,000 for accredited undergraduate degree courses and up to $12,000 per calendar year for "
                    "graduate degree coursework upon achieving a grade of B or better."
                ),
            },
        ],
    },
    {
        "test_id": "TC-03",
        "name": "Overtime Exemption and Salaried Deductions",
        "query": "Which employees are excluded from federal and state overtime provisions, and under what rules are deductions allowed from their salary?",
        "target_source": "Section 'Employment Classification' (Page 11) & 'Compensation - Payroll Deductions' (Page 13)",
        "target_keywords": ["Exempt Employees", "excluded from overtime", "disciplinary suspensions", "full-day absences"],
        "golden_chunk": {
            "id": "golden_tc03",
            "section": "Employment Classification & Payroll Deductions (Pages 11, 13)",
            "text": (
                "Employment Classification & Payroll Deductions: Exempt Employees are excluded from federal and state overtime pay provisions. "
                "Intertek pays exempt staff on a predetermined salary basis. Deductions from an exempt employee's salary are strictly prohibited "
                "except under authorized conditions: initial or terminal weeks of employment, full-day absences for personal reasons, full-day "
                "absences for sickness or disability under a bona fide sick leave plan, or unpaid disciplinary suspensions imposed in good faith "
                "for infractions of workplace conduct rules or major safety violations."
            ),
        },
        "distractors": [
            {
                "id": "tc03_distractor_a",
                "label": "Overtime Compensation (Page 14)",
                "text": (
                    "Compensation - Overtime Compensation: Non-exempt hourly employees who work in excess of 40 hours during a designated "
                    "workweek are eligible to receive overtime compensation calculated at 1.5 times their regular base rate of pay. "
                    "All overtime must be pre-approved by the department manager."
                ),
            },
            {
                "id": "tc03_distractor_b",
                "label": "Time Reporting (Page 13)",
                "text": (
                    "Compensation - Time Reporting Procedures: All hourly non-exempt employees must accurately record standard daily working hours, "
                    "recording exact arrival, departure, and meal break times using the electronic timekeeping portal. Falsification of time records "
                    "results in disciplinary action."
                ),
            },
            {
                "id": "tc03_distractor_c",
                "label": "Shift Differential (Page 14)",
                "text": (
                    "Compensation - Shift Differential: Non-exempt employees assigned to second or third shifts receive an additional hourly "
                    "shift differential added to their standard hourly wage for all hours worked during designated evening or weekend operating shifts."
                ),
            },
        ],
    },
    {
        "test_id": "TC-04",
        "name": "Resignation Notice vs. Leave Notice Requirements",
        "query": "How much advance notice must an employee provide when resigning in order to remain in good standing, and can PTO be used during this time?",
        "target_source": "Section 'Employment Records - Separation from Employment' (Page 41)",
        "target_keywords": ["two weeks' notice", "in good standing", "rehire", "not permitted to utilize PTO"],
        "golden_chunk": {
            "id": "golden_tc04",
            "section": "Employment Records - Separation from Employment (Page 41)",
            "text": (
                "Employment Records - Separation from Employment: When resigning from employment, an employee must provide at least two (2) weeks' "
                "advance written notice specifying their final working day in order to separate in good standing and remain eligible for future rehire. "
                "Employees are explicitly not permitted to utilize Paid Time Off (PTO), vacation, or sick leave during this two-week resignation notice period."
            ),
        },
        "distractors": [
            {
                "id": "tc04_distractor_a",
                "label": "Procedure for Requesting FMLA-protected Leave (Page 22)",
                "text": (
                    "Employee Benefits - FMLA Leave Request Procedure: When the need for Family and Medical Leave (FMLA) is foreseeable, "
                    "an employee must provide at least thirty (30) days' advance notice to Human Resources before the leave is scheduled to begin."
                ),
            },
            {
                "id": "tc04_distractor_b",
                "label": "Personal Leave of Absence (Page 23)",
                "text": (
                    "Employee Benefits - Personal Leave of Absence: Requests for an unpaid personal leave of absence must be submitted in writing "
                    "to the department manager at least ten (10) days prior to the desired commencement date and requires executive vice president approval."
                ),
            },
            {
                "id": "tc04_distractor_c",
                "label": "Unscheduled Absenteeism Notification (Page 12)",
                "text": (
                    "Workplace Guidelines - Unscheduled Absenteeism: In cases of sudden illness or emergency, employees must notify their immediate "
                    "supervisor at least one (1) hour prior to their scheduled shift start time to report their absence."
                ),
            },
        ],
    },
    {
        "test_id": "TC-05",
        "name": "Medical Marijuana in Legalized States",
        "query": "Is an employee protected from termination if they test positive for marijuana in a state where recreational or medical marijuana has been legalized?",
        "target_source": "Section 'Health & Safety - Drug-Free Workplace Policy' (Page 39)",
        "target_keywords": ["legalized", "recreational use", "positive for marijuana", "terminated from employment", "drug-free workplace"],
        "golden_chunk": {
            "id": "golden_tc05",
            "section": "Health & Safety - Drug-Free Workplace Policy (Page 39)",
            "text": (
                "Health & Safety - Drug-Free Workplace Policy: Intertek maintains a strict drug-free workplace policy across all company locations "
                "regardless of state laws. An employee who tests positive for marijuana in a state where recreational or medical marijuana has been "
                "legalized is not protected from termination. While they may not be subject to state criminal charges, they remain in violation of "
                "Intertek's policy and are subject to immediate termination of employment."
            ),
        },
        "distractors": [
            {
                "id": "tc05_distractor_a",
                "label": "Tobacco-Free Workplace Policy (Page 40)",
                "text": (
                    "Health & Safety - Tobacco-Free Workplace Policy: Intertek maintains a tobacco-free environment. Smoking, vaping, electronic cigarettes, "
                    "and smokeless tobacco products are prohibited inside all company buildings, vehicles, and customer facilities, except in designated outdoor zones."
                ),
            },
            {
                "id": "tc05_distractor_b",
                "label": "Pre-Employment Screening (Page 9)",
                "text": (
                    "Employment Policies - Pre-Employment Drug Screening: All conditional job offers require drug testing in full compliance with federal, "
                    "state, and municipal regulations. Inability to produce a negative result disqualifies the applicant from hire."
                ),
            },
            {
                "id": "tc05_distractor_c",
                "label": "Reasonable Accommodations for Disabilities (Page 7)",
                "text": (
                    "General Employment - Reasonable Accommodations: Intertek provides reasonable accommodations for qualified individuals with known physical "
                    "or mental disabilities, engaging in an interactive process with Human Resources to identify appropriate workplace adjustments."
                ),
            },
        ],
    },
    {
        "test_id": "TC-06",
        "name": "Shift Holiday Pay Calculation",
        "query": "If a non-exempt employee is regularly scheduled to work a 12-hour shift on a day a designated company holiday falls, how many hours of holiday pay will they receive?",
        "target_source": "Section 'Employee Benefits - Holiday Time' (Page 16)",
        "target_keywords": ["12-hour shift", "twelve (12) hours of holiday pay", "more than eight (8) hours"],
        "golden_chunk": {
            "id": "golden_tc06",
            "section": "Employee Benefits - Holiday Time (Page 16)",
            "text": (
                "Employee Benefits - Holiday Time: Non-exempt employees who are regularly scheduled to work shifts exceeding eight (8) hours per day, "
                "such as a twelve (12) hour shift schedule, will receive holiday pay equal to their regular daily scheduled shift length—receiving "
                "twelve (12) hours of holiday pay when a designated holiday falls on their work day."
            ),
        },
        "distractors": [
            {
                "id": "tc06_distractor_a",
                "label": "General Holiday Pay allocation (Page 16)",
                "text": (
                    "Employee Benefits - General Holiday Pay: Eligible full-time regular employees generally receive eight (8) hours of paid holiday time "
                    "at their standard straight-time base rate for each of the company's designated annual holidays."
                ),
            },
            {
                "id": "tc06_distractor_b",
                "label": "Part-Time Holiday Pay proration (Page 16)",
                "text": (
                    "Employee Benefits - Part-Time Holiday Pay: Regular part-time employees scheduled for 30 or more hours per week receive holiday pay "
                    "calculated on a prorated basis of 75% of the standard holiday benefit (equivalent to six hours of pay)."
                ),
            },
            {
                "id": "tc06_distractor_c",
                "label": "Worked Holiday Pay rule (Page 16)",
                "text": (
                    "Employee Benefits - Working on Holidays: Non-exempt hourly employees required to physically perform work on a scheduled company holiday "
                    "receive their holiday pay entitlement plus 1.5 times their regular base hourly rate for all actual hours worked during the holiday."
                ),
            },
        ],
    },
    {
        "test_id": "TC-07",
        "name": "Gift Thresholds & Permissible Exceptions",
        "query": "What is the maximum monetary threshold for unsolicited holiday promotional gifts before they must be declined or declared as a conflict of interest?",
        "target_source": "Section 'Employee Code of Conduct - Conflict of Interest & Gifts, Gratuities, Entertainment and Ethics' (Page 31)",
        "target_keywords": ["$25", "nominal value", "conflict of interest", "unsolicited promotional material"],
        "golden_chunk": {
            "id": "golden_tc07",
            "section": "Employee Code of Conduct - Conflict of Interest & Gifts (Page 31)",
            "text": (
                "Employee Code of Conduct - Conflict of Interest & Gifts: Employees may accept unsolicited gifts, promotional materials (e.g., pens, "
                "notepads, mugs), or holiday tokens of nominal value not exceeding $25. Any unsolicited gift or entertainment with a monetary value greater "
                "than $25 must be politely declined, returned, or disclosed in writing to the Compliance Officer, as it may be construed as an improper "
                "personal benefit or conflict of interest."
            ),
        },
        "distractors": [
            {
                "id": "tc07_distractor_a",
                "label": "Business Expense Reimbursement (Page 14)",
                "text": (
                    "Compensation - Travel & Business Expense Reimbursement: Employees authorized to travel on company business will be reimbursed for "
                    "reasonable meal and lodging expenses. Itemized expense reports with receipts must be submitted through the portal within 30 days."
                ),
            },
            {
                "id": "tc07_distractor_b",
                "label": "Solicitation and Distribution (Page 33)",
                "text": (
                    "Employee Code of Conduct - Solicitation and Distribution: Soliciting contributions, selling raffle tickets, or distributing commercial "
                    "literature by employees is strictly prohibited during working time or within operational work areas."
                ),
            },
            {
                "id": "tc07_distractor_c",
                "label": "Anti-Bribery Guidance (Page 34)",
                "text": (
                    "Employee Code of Conduct - Anti-Bribery and Corruption: Intertek strictly prohibits offering, promising, or giving anything of value, "
                    "bribes, or kickbacks to government officials, commercial partners, or clients to secure an improper business advantage."
                ),
            },
        ],
    },
    {
        "test_id": "TC-08",
        "name": "Banked PTO & Sick Leave Exhaustion Sequence",
        "query": "Can an employee use their grandfathered banked PTO or Sick Leave to supplement income during a personal vacation?",
        "target_source": "Section 'Employee Benefits - Banked PTO and/or Sick Leave' (Pages 17–18)",
        "target_keywords": ["Banked PTO", "FMLA Leave", "supplement pay", "after 100% of current year"],
        "golden_chunk": {
            "id": "golden_tc08",
            "section": "Employee Benefits - Banked PTO and Sick Leave (Pages 17–18)",
            "text": (
                "Employee Benefits - Banked PTO and Sick Leave: Grandfathered Banked PTO and Banked Sick Leave cannot be used for regular personal vacations. "
                "Banked leave can only be utilized to supplement pay during an approved, otherwise unpaid medical or FMLA leave, and strictly only "
                "after 100% of current year annualized PTO or Vacation/Sick entitlement has been completely exhausted."
            ),
        },
        "distractors": [
            {
                "id": "tc08_distractor_a",
                "label": "Paid Leave General Overview (Page 17)",
                "text": (
                    "Employee Benefits - Paid Time Off Accrual: Eligible full-time employees accrue standard PTO each bi-weekly pay period based on years "
                    "of continuous service. PTO can be scheduled for rest, vacations, personal appointments, or family matters subject to advance supervisor approval."
                ),
            },
            {
                "id": "tc08_distractor_b",
                "label": "Unpaid Time Off (Page 18)",
                "text": (
                    "Employee Benefits - Unpaid Absences: An employee requesting unpaid time off must obtain prior written approval from their department head. "
                    "Unpaid leave is granted only when all existing paid leave balances have been exhausted."
                ),
            },
            {
                "id": "tc08_distractor_c",
                "label": "Separation payout of PTO (Page 17)",
                "text": (
                    "Employee Benefits - PTO Payout at Separation: Upon voluntary resignation with proper two weeks' notice, unused accrued current-year PTO "
                    "is paid out. Grandfathered banked PTO and sick leave balances are strictly forfeited upon termination and ineligible for separation payout."
                ),
            },
        ],
    },
    {
        "test_id": "TC-09",
        "name": "In-Vehicle Cell Phone Operations vs. General Mobile Policy",
        "query": "What are the rules regarding hands-free vs. texting and hand-held devices when driving an Intertek company vehicle?",
        "target_source": "Section 'Compensation - Company Vehicles' (Pages 14–15) & Section 'Cellular and Satellite Telephones' (Page 32)",
        "target_keywords": ["company vehicle", "texting", "keying function", "hands-free", "driving for business purposes"],
        "golden_chunk": {
            "id": "golden_tc09",
            "section": "Company Vehicles & Mobile Telephone Usage (Pages 14–15, 32)",
            "text": (
                "Company Vehicles & Mobile Telephone Usage: Employees operating an Intertek company vehicle or driving for business purposes are strictly "
                "prohibited from texting, emailing, or utilizing any keying or typing function on a cell phone or handheld device while the vehicle is in operation. "
                "All phone calls while driving for business purposes must utilize an approved hands-free accessory; holding or operating handheld cellular phones "
                "while driving is strictly prohibited."
            ),
        },
        "distractors": [
            {
                "id": "tc09_distractor_a",
                "label": "Electronic Communications (Pages 31–32)",
                "text": (
                    "Employee Code of Conduct - Electronic Communications: Company computers, network equipment, and digital accounts are company property. "
                    "The company reserves the right to audit, monitor, and inspect electronic communication logs, internet history, and cloud files at any time."
                ),
            },
            {
                "id": "tc09_distractor_b",
                "label": "Personal calls on company mobile phones (Page 32)",
                "text": (
                    "Workplace Guidelines - Company Cellular Phones: Company-issued cellular phones are provided for official business communications. "
                    "Incidental, minimal personal phone calls are permitted provided they do not incur substantial roaming costs or detract from productivity."
                ),
            },
            {
                "id": "tc09_distractor_c",
                "label": "Company vehicle maintenance and accident reporting (Page 15)",
                "text": (
                    "Compensation - Company Vehicle Maintenance: Authorized operators of company vehicles must ensure regular oil changes and vehicle safety checks. "
                    "Any traffic collision or vehicle damage must be reported to the Fleet Coordinator within 24 hours of occurrence."
                ),
            },
        ],
    },
    {
        "test_id": "TC-10",
        "name": "Internal Transfer Eligibility Constraints",
        "query": "What are all the requirements an employee must satisfy before becoming eligible to apply for an internal job transfer?",
        "target_source": "Section 'Education, Training & Professional Development - Advancement and Transfer' (Page 27)",
        "target_keywords": ["minimum of twelve (12) months", "good standing", "performance improvement plan", "discuss with their manager"],
        "golden_chunk": {
            "id": "golden_tc10",
            "section": "Advancement and Transfer - Eligibility Requirements (Page 27)",
            "text": (
                "Advancement and Transfer - Eligibility Requirements: To be eligible to apply for an internal job transfer or promotional vacancy, "
                "an employee must satisfy all of the following requirements: remain in their current position or department for a minimum of twelve (12) "
                "consecutive months, maintain satisfactory job performance and be in good standing, cannot be currently on any active Performance Improvement "
                "Plan (PIP) or disciplinary warning, and must discuss the open opportunity with their manager prior to applying."
            ),
        },
        "distractors": [
            {
                "id": "tc10_distractor_a",
                "label": "Introductory Period (Pages 10–11)",
                "text": (
                    "Employment Policies - Introductory Period: The initial ninety (90) days of employment serve as an evaluation period during which "
                    "job suitability is assessed. Employees within their introductory period are not eligible for job transfers or promotions."
                ),
            },
            {
                "id": "tc10_distractor_b",
                "label": "Job Posting (Page 27)",
                "text": (
                    "Advancement and Transfer - Job Postings: All regular job openings are posted on the internal employee portal for a minimum of "
                    "five (5) business days before external candidates are actively recruited, providing existing staff opportunity for career progression."
                ),
            },
            {
                "id": "tc10_distractor_c",
                "label": "Employee Referral Program (Page 19)",
                "text": (
                    "Employee Benefits - Employee Referral Program: Employees who refer qualified candidates hired for regular full-time roles "
                    "are eligible to receive a referral award, payable following the referred candidate's completion of ninety (90) days of active service."
                ),
            },
        ],
    },
]


@pytest.fixture(scope="session")
def reranker() -> BgeReranker:
    """Session-scoped BGE Reranker instance to prevent reload latency across test runs."""
    return BgeReranker()


class TestRerankerBenchmark:
    """Automated evaluation suite for cross-encoder reranking accuracy against adversarial distractors."""

    @pytest.mark.parametrize(
        "case",
        BENCHMARK_DATASET,
        ids=[f"{c['test_id']}_{c['name'][:30].replace(' ', '_')}" for c in BENCHMARK_DATASET],
    )
    def test_reranker_case_distractor_suppression(self, reranker: BgeReranker, case: Dict[str, Any]):
        """
        Evaluates a single benchmark case against 3 adversarial distractors:
        - Simulates bi-encoder retrieval returning distractors first (golden chunk placed at bottom).
        - Asserts Hit Rate@1: Golden chunk is ranked #1.
        - Asserts Hit Rate@3: Golden chunk is within Top 3.
        - Asserts Distractor Suppression: No distractor has a higher score than the golden chunk.
        """
        query = case["query"]
        golden_chunk = case["golden_chunk"]
        distractors = case["distractors"]

        # Construct candidate pool: Place distractors first (ranks 1..3) and golden chunk last (rank 4)
        # to rigorously test reranker's ability to lift the ground-truth chunk over lexical distractors.
        candidate_pool: List[Dict[str, Any]] = [
            {
                "id": d["id"],
                "text": d["text"],
                "label": d["label"],
                "is_golden": False,
            }
            for d in distractors
        ]
        candidate_pool.append({
            "id": golden_chunk["id"],
            "text": golden_chunk["text"],
            "label": golden_chunk["section"],
            "is_golden": True,
        })

        top_k = len(candidate_pool)
        reranked = reranker.rerank(query=query, candidates=candidate_pool, top_k=top_k)

        # Identify golden chunk performance
        golden_rank = next((i + 1 for i, c in enumerate(reranked) if c.get("is_golden")), None)
        assert golden_rank is not None, f"Golden chunk {golden_chunk['id']} missing from reranked output!"

        golden_result = reranked[golden_rank - 1]
        golden_score = golden_result.get("_rerank_score", 0.0)

        # Identify any outranking distractors
        outranking_distractors = [
            c for i, c in enumerate(reranked)
            if not c.get("is_golden") and i < (golden_rank - 1)
        ]

        top_distractor = max(
            (c for c in reranked if not c.get("is_golden")),
            key=lambda x: x.get("_rerank_score", float("-inf")),
        )
        top_distractor_score = top_distractor.get("_rerank_score", 0.0)
        margin = golden_score - top_distractor_score
        reciprocal_rank = 1.0 / golden_rank

        # Diagnostic log
        log_lines = [
            f"\n{'='*75}",
            f"EVALUATION RESULT: [{case['test_id']}] {case['name']}",
            f"Query: \"{query}\"",
            f"Target Source: {case['target_source']}",
            f"Golden Chunk Rank: #{golden_rank} (Score: {golden_score:.4f})",
            f"Top Distractor: {top_distractor.get('label')} (Score: {top_distractor_score:.4f})",
            f"Score Margin: {margin:+.4f}",
            f"Reciprocal Rank (RR): {reciprocal_rank:.4f}",
            "-" * 75,
            "RERANKED CANDIDATES (Top to Bottom):",
        ]
        for idx, item in enumerate(reranked, 1):
            tag = "[GOLDEN TARGET]" if item.get("is_golden") else "[DISTRACTOR]   "
            log_lines.append(
                f"  #{idx} {tag} Score: {item.get('_rerank_score', 0.0):.4f} | "
                f"ID: {item.get('id')} | Label: {item.get('label')}"
            )
        log_lines.append(f"{'='*75}\n")
        details_str = "\n".join(log_lines)

        # Detailed failure diagnostic if a distractor outranked golden chunk
        if outranking_distractors:
            failure_msg = (
                f"\n[RERANKER FAILURE] Distractor Suppression Failed on {case['test_id']}!\n"
                f"Golden Chunk '{golden_chunk['id']}' ranked #{golden_rank} with score {golden_score:.4f}.\n"
                f"The following {len(outranking_distractors)} distractor(s) incorrectly outranked the golden chunk:\n"
            )
            for d in outranking_distractors:
                failure_msg += (
                    f"  - [{d.get('id')}] {d.get('label')}: score={d.get('_rerank_score'):.4f} "
                    f"(+{d.get('_rerank_score') - golden_score:.4f} above golden)\n"
                )
            failure_msg += details_str
            pytest.fail(failure_msg)

        # Assert Hit Rate@1, Hit Rate@3, and Distractor Suppression
        assert golden_rank == 1, f"Expected Golden Chunk to rank #1, but was #{golden_rank}.\n{details_str}"
        assert golden_rank <= 3, f"Expected Golden Chunk to rank in Top 3, but was #{golden_rank}.\n{details_str}"
        assert margin > 0.0, f"Expected positive score margin over top distractor, got {margin}.\n{details_str}"


def test_aggregate_reranker_benchmark_summary(reranker: BgeReranker, capsys):
    """
    Executes the complete 10-query benchmark dataset and produces a standardized
    QA/Evaluation report calculating aggregate Hit Rate@1, Hit Rate@3, and MRR.
    """
    results = []
    
    for case in BENCHMARK_DATASET:
        query = case["query"]
        golden_chunk = case["golden_chunk"]
        distractors = case["distractors"]

        candidate_pool: List[Dict[str, Any]] = [
            {
                "id": d["id"],
                "text": d["text"],
                "label": d["label"],
                "is_golden": False,
            }
            for d in distractors
        ]
        # Golden chunk is appended at the bottom
        candidate_pool.append({
            "id": golden_chunk["id"],
            "text": golden_chunk["text"],
            "label": golden_chunk["section"],
            "is_golden": True,
        })

        reranked = reranker.rerank(query=query, candidates=candidate_pool, top_k=len(candidate_pool))
        golden_rank = next((i + 1 for i, c in enumerate(reranked) if c.get("is_golden")), len(candidate_pool) + 1)
        golden_score = next((c.get("_rerank_score", 0.0) for c in reranked if c.get("is_golden")), 0.0)
        top_distractor_score = max(c.get("_rerank_score", 0.0) for c in reranked if not c.get("is_golden"))

        results.append({
            "test_id": case["test_id"],
            "name": case["name"],
            "golden_rank": golden_rank,
            "hit_at_1": 1.0 if golden_rank == 1 else 0.0,
            "hit_at_3": 1.0 if golden_rank <= 3 else 0.0,
            "rr": 1.0 / golden_rank,
            "golden_score": golden_score,
            "top_distractor_score": top_distractor_score,
            "margin": golden_score - top_distractor_score,
        })

    total_queries = len(results)
    hit_rate_at_1 = sum(r["hit_at_1"] for r in results) / total_queries
    hit_rate_at_3 = sum(r["hit_at_3"] for r in results) / total_queries
    mrr = sum(r["rr"] for r in results) / total_queries
    avg_margin = sum(r["margin"] for r in results) / total_queries

    report_lines = [
        "",
        "=" * 88,
        "                    RAG RERANKER BENCHMARK EVALUATION REPORT",
        "                         Intertek Employee Handbook Set",
        "=" * 88,
        f"Evaluator Model:        {getattr(reranker, 'model_name', 'BGE-Reranker-Base')}",
        f"Total Benchmark Cases:  {total_queries}",
        f"Candidate Pool per Case: 4 (1 Golden Target + 3 Adversarial Distractors)",
        "-" * 88,
        f"{'Case ID':<8} {'Case Name':<40} {'Rank':<6} {'Score':<8} {'Top Dist':<8} {'Margin':<8} {'RR':<6}",
        "-" * 88,
    ]
    for r in results:
        report_lines.append(
            f"{r['test_id']:<8} {r['name'][:38]:<40} #{r['golden_rank']:<5} "
            f"{r['golden_score']:<8.4f} {r['top_distractor_score']:<8.4f} {r['margin']:<+8.4f} {r['rr']:<6.4f}"
        )
    report_lines.extend([
        "-" * 88,
        "AGGREGATE PERFORMANCE METRICS:",
        f"  - Hit Rate@1 (Top-1 Accuracy):         {hit_rate_at_1:.2%}  ({int(hit_rate_at_1 * total_queries)}/{total_queries})",
        f"  - Hit Rate@3 (Top-3 Retrieval Recall):  {hit_rate_at_3:.2%}  ({int(hit_rate_at_3 * total_queries)}/{total_queries})",
        f"  - Mean Reciprocal Rank (MRR):           {mrr:.4f}",
        f"  - Average Separation Margin:            {avg_margin:+.4f}",
        "=" * 88,
    ])
    full_report = "\n".join(report_lines)
    print(full_report)

    # Statistical Threshold Assertions
    assert hit_rate_at_1 >= 0.80, f"Hit Rate@1 ({hit_rate_at_1:.2%}) failed minimum benchmark threshold (80.0%)!"
    assert hit_rate_at_3 >= 0.90, f"Hit Rate@3 ({hit_rate_at_3:.2%}) failed minimum benchmark threshold (90.0%)!"
    assert mrr >= 0.85, f"MRR ({mrr:.4f}) failed minimum benchmark threshold (0.8500)!"
