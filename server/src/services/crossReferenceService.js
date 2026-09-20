const Checklist = require('../models/Checklist');
const Document = require('../models/Document');

/**
 * Standard Due Diligence Tasks Template
 */
const DEFAULT_DILIGENCE_TASKS = [
    { id: 'task_title_ec', title: 'Verify Encumbrance Certificate (EC) for 30+ Years', category: 'TITLE' },
    { id: 'task_title_chain', title: 'Verify Title Deed & 30-Year Chain of Documents', category: 'TITLE' },
    { id: 'task_rera_reg', title: 'Verify MahaRERA Project Registration & Sanctioned Plans', category: 'RERA' },
    { id: 'task_rera_escrow', title: 'Verify Designated 70% Project Escrow Account', category: 'RERA' },
    { id: 'task_possession_date', title: 'Verify Possession Timeline and Agreement Handover Dates', category: 'POSSESSION' },
    { id: 'task_oc_cc', title: 'Verify Occupancy Certificate (OC) & Completion Certificate (CC)', category: 'POSSESSION' },
    { id: 'task_payment_milestones', title: 'Verify Payment Milestone Schedule & Construction Linked Plan', category: 'PAYMENT' },
    { id: 'task_forfeiture_terms', title: 'Verify 10% Forfeiture Ceiling & Cancellation Refund Terms (RERA S. 13)', category: 'PAYMENT' },
    { id: 'task_society_khata', title: 'Inspect Society NOC & Share Certificate / Khata Transfer', category: 'SOCIETY' },
    { id: 'task_tax_receipts', title: 'Verify Latest Property Tax & Utility Clearance Receipts', category: 'SOCIETY' },
    { id: 'task_registered_agreement', title: 'Draft & Execute Registered Agreement for Sale (Section 17 Registration Act)', category: 'LEGAL' }
];

/**
 * Categorizes a document finding into one or more due diligence domains
 */
function classifyFinding(finding) {
    const categories = new Set();
    const textBlob = [
        finding.title || '',
        finding.text || '',
        finding.reason || '',
        finding.legalFinding || '',
        finding.findingCategory || '',
        finding.buyerImpact || '',
        finding.recommendation || '',
        (finding.statutoryCitations || []).join(' '),
        (finding.reraReferences || []).join(' ')
    ].join(' ').toLowerCase();

    const citations = (finding.statutoryCitations || []).concat(finding.reraReferences || []).map(c => c.toLowerCase());
    const findingCategory = (finding.findingCategory || '').toLowerCase();

    // Helper regex matcher
    const hasWord = (regex) => regex.test(textBlob);

    // 1. TITLE / OWNERSHIP / SUCCESSION / ENCUMBRANCE
    if (
        findingCategory.includes('title') ||
        findingCategory.includes('documentation') ||
        hasWord(/\b(title|ownership|encumbrance|succession|legal heir|coparcenary|hindu succession|7\/12|mutation|patta|khata certificate|chain of title|chain of document|sub-registrar|non-encumbrance)\b/i) ||
        citations.some(c => c.includes('hindu succession') || c.includes('transfer of property act') || c.includes('section 55'))
    ) {
        categories.add('TITLE');
    }

    // 2. RERA / PROJECT REGISTRATION / APPROVALS
    if (
        hasWord(/\b(rera|maharera|promoter obligations?|sanctioned layout|sanctioned plan|escrow account|commencement certificate|layout approval|rera registration)\b/i) ||
        citations.some(c => c.includes('rera') || c.includes('section 3') || c.includes('section 4') || c.includes('section 11'))
    ) {
        categories.add('RERA');
    }

    // 3. POSSESSION / DELAY / COMPLETION
    if (
        hasWord(/\b(possession|handover|possession date|delay compensation|grace period|completion certificate|occupancy certificate|handover timeline|fit-out possession)\b/i) ||
        citations.some(c => c.includes('section 18') || c.includes('delay compensation') || c.includes('delay interest'))
    ) {
        categories.add('POSSESSION');
    }

    // 4. PAYMENT / FORFEITURE / PENALTY / CONSIDERATION
    if (
        hasWord(/\b(forfeit|earnest money|booking amount|cancellation fee|cancellation charge|payment schedule|construction linked plan|payment milestone|section 74|penal interest|deferred consideration|charge on property)\b/i) ||
        citations.some(c => c.includes('contract act') || c.includes('section 74') || c.includes('section 13'))
    ) {
        categories.add('PAYMENT');
    }

    // 5. SOCIETY / KHATA / TAXES
    if (
        hasWord(/\b(society noc|share certificate|khata transfer|property tax|municipal dues|maintenance arrears|co-operative society|society maintenance)\b/i) ||
        citations.some(c => c.includes('co-operative') || c.includes('municipal'))
    ) {
        categories.add('SOCIETY');
    }

    // 6. GENERAL LEGAL / REGISTRATION
    if (
        hasWord(/\b(registration act|unregistered agreement|stamp duty|arbitration clause|exclusive jurisdiction|unilateral indemnity)\b/i) ||
        citations.some(c => c.includes('registration act') || c.includes('section 17') || c.includes('stamp'))
    ) {
        categories.add('LEGAL');
    }

    // Default fallback if no category matched but it's an issue
    if (categories.size === 0) {
        categories.add('LEGAL');
    }

    return Array.from(categories);
}

/**
 * Checks if a specific checklist item title matches a target category or keywords
 */
function itemMatchesCategory(itemTitle, category) {
    const t = (itemTitle || '').toLowerCase();
    switch (category) {
        case 'TITLE':
            return t.includes('title') || t.includes('encumbrance') || t.includes('chain') || t.includes('ownership') || t.includes('deed') || t.includes('mutation');
        case 'RERA':
            return t.includes('rera') || t.includes('sanction') || t.includes('escrow') || t.includes('promoter') || t.includes('sanctioned plan');
        case 'POSSESSION':
            return t.includes('possession') || t.includes('handover') || t.includes('occupancy') || t.includes('completion') || t.includes('handover date');
        case 'PAYMENT':
            return t.includes('payment') || t.includes('milestone') || t.includes('forfeit') || t.includes('refund') || t.includes('schedule') || t.includes('forfeiture');
        case 'SOCIETY':
            return t.includes('society') || t.includes('noc') || t.includes('khata') || t.includes('share certificate') || t.includes('property tax');
        case 'LEGAL':
            return t.includes('registered agreement') || t.includes('registration act') || t.includes('stamp duty') || t.includes('conveyance deed') || t.includes('dispute resolution') || t.includes('arbitration');
        default:
            return false;
    }
}

/**
 * Synchronizes detected document issues from a single Document with all relevant user Checklists.
 * Safe, idempotent, non-destructive to completed user tasks.
 */
async function syncDocumentIssuesWithChecklists(userId, document) {
    if (!userId || !document) return [];

    const docIdStr = document._id.toString();
    const docTitle = document.title || document.fileName || 'Property Agreement';

    // 1. Extract only actionable findings (HIGH_RISK and CAUTION)
    const issueClauses = (document.analysis || []).filter(
        c => c.riskLevel === 'HIGH_RISK' || c.riskLevel === 'CAUTION'
    );

    if (issueClauses.length === 0) {
        return [];
    }

    // 2. Fetch existing checklists for user
    let checklists = await Checklist.find({ userId });

    // If user has no checklists yet, create the standard Due Diligence Checklist
    if (!checklists || checklists.length === 0) {
        const defaultChecklist = new Checklist({
            userId,
            type: 'due_diligence_' + userId,
            title: `Due Diligence: ${docTitle.substring(0, 35)}`,
            items: DEFAULT_DILIGENCE_TASKS.map((task, idx) => ({
                id: (idx + 1).toString(),
                title: task.title,
                isCompleted: false,
                status: 'NOT_STARTED',
                linkedIssues: []
            }))
        });
        await defaultChecklist.save();
        checklists = [defaultChecklist];
    }

    let modifiedChecklists = [];

    // 3. Process each checklist
    for (const checklist of checklists) {
        let isChecklistModified = false;

        for (const finding of issueClauses) {
            const categories = classifyFinding(finding);

            const linkedIssuePayload = {
                documentId: docIdStr,
                documentTitle: docTitle,
                clauseId: finding.clauseId || 'CLAUSE',
                clauseTitle: finding.title || finding.clauseId || 'Legal Clause',
                riskLevel: finding.riskLevel || 'HIGH_RISK',
                findingCategory: finding.findingCategory || 'Potential legal concern',
                reason: finding.reason || 'Document concern detected.',
                legalFinding: finding.legalFinding || '',
                statutoryCitations: finding.statutoryCitations || [],
                reraReferences: finding.reraReferences || [],
                buyerImpact: finding.buyerImpact || '',
                recommendation: finding.recommendation || '',
                flaggedAt: new Date()
            };

            // Match against checklist items
            let matchedAnyItem = false;

            for (const item of checklist.items) {
                const matches = categories.some(cat => itemMatchesCategory(item.title, cat));

                if (matches) {
                    matchedAnyItem = true;
                    if (!item.linkedIssues) {
                        item.linkedIssues = [];
                    }

                    // Deduplicate: Check if this exact issue (docId + clauseId) is already linked
                    const existingIndex = item.linkedIssues.findIndex(
                        li => li.documentId === docIdStr && li.clauseId === finding.clauseId
                    );

                    if (existingIndex >= 0) {
                        // Update existing link with latest details
                        item.linkedIssues[existingIndex] = {
                            ...item.linkedIssues[existingIndex].toObject?.() || item.linkedIssues[existingIndex],
                            ...linkedIssuePayload
                        };
                    } else {
                        // Add new linked issue
                        item.linkedIssues.push(linkedIssuePayload);
                    }

                    // Update item status: Never override VERIFIED if user manually completed it
                    if (!item.isCompleted) {
                        item.status = 'FLAGGED';
                    } else {
                        item.status = 'VERIFIED';
                    }

                    isChecklistModified = true;
                }
            }

            // If no existing item in custom checklist matched this category, append a new targeted task
            if (!matchedAnyItem) {
                const matchingDefaultTask = DEFAULT_DILIGENCE_TASKS.find(t => categories.includes(t.category));
                const newTitle = matchingDefaultTask ? matchingDefaultTask.title : `Verify ${finding.title || 'Agreement Clause'}`;
                
                const newItem = {
                    id: Date.now().toString() + Math.floor(Math.random() * 1000),
                    title: newTitle,
                    isCompleted: false,
                    status: 'FLAGGED',
                    linkedIssues: [linkedIssuePayload]
                };
                checklist.items.push(newItem);
                isChecklistModified = true;
            }
        }

        if (isChecklistModified) {
            checklist.updatedAt = new Date();
            await checklist.save();
            modifiedChecklists.push(checklist);
        }
    }

    return modifiedChecklists;
}

/**
 * Synchronizes all user documents with their checklists
 */
async function syncAllUserDocuments(userId) {
    if (!userId) return [];
    const docs = await Document.find({ userId, analysisStatus: 'completed' });
    let results = [];
    for (const doc of docs) {
        const res = await syncDocumentIssuesWithChecklists(userId, doc);
        results.push(...res);
    }
    return results;
}

module.exports = {
    DEFAULT_DILIGENCE_TASKS,
    classifyFinding,
    itemMatchesCategory,
    syncDocumentIssuesWithChecklists,
    syncAllUserDocuments
};
