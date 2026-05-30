// Initialize Lucide Icons
lucide.createIcons();

// --- Data Layer ---
let patients = [];
let currentPatient = null;

// Fetch patients from the backend API
async function loadPatients() {
    try {
        patientListEl.innerHTML = '<div style="padding: 1rem; color: #94a3b8;">Loading patients...</div>';
        const response = await fetch('/api/patients');
        patients = await response.json();
        renderPatientList();
    } catch (error) {
        console.error("Failed to load patient data:", error);
        patientListEl.innerHTML = '<div style="padding: 1rem; color: #ef4444;">Error loading data from backend. Make sure the server is running.</div>';
    }
}

// --- DOM Elements ---
const searchInput = document.getElementById('searchInput');
const patientListEl = document.getElementById('patientList');
const dashboardContent = document.getElementById('dashboardContent');
const emptyState = document.getElementById('emptyState');

// Cards
const patientProfileEl = document.getElementById('patientProfile');
const patientSummaryEl = document.getElementById('patientSummary');
const medicalDetailsEl = document.getElementById('medicalDetails');
const recommendationListEl = document.getElementById('recommendationList');
const recentEncountersEl = document.getElementById('recentEncounters');

// Modal
const addPatientBtn = document.getElementById('addPatientBtn');
const patientModal = document.getElementById('patientModal');
const closeModalBtn = document.getElementById('closeModalBtn');
const addPatientForm = document.getElementById('addPatientForm');

// --- Functions ---

function renderPatientList(query = '') {
    patientListEl.innerHTML = '';
    const filtered = patients.filter(p => p.name.toLowerCase().includes(query.toLowerCase()));
    
    if (filtered.length === 0) {
        patientListEl.innerHTML = '<div style="padding: 1rem; color: #94a3b8;">No patients found.</div>';
        return;
    }

    filtered.forEach(p => {
        const div = document.createElement('div');
        div.className = `patient-item ${currentPatient && currentPatient.id === p.id ? 'active' : ''}`;
        div.innerHTML = `
            <div class="patient-item-header">
                <span class="patient-name">${p.name}</span>
                <span class="patient-id">${p.id}</span>
            </div>
            <div style="font-size: 0.8rem; color: var(--text-muted)">Age: ${p.age}</div>
        `;
        div.addEventListener('click', () => selectPatient(p.id));
        patientListEl.appendChild(div);
    });
}

function selectPatient(id) {
    currentPatient = patients.find(p => p.id === id);
    renderPatientList(searchInput.value);
    
    emptyState.classList.add('hidden');
    dashboardContent.classList.remove('hidden');
    
    updateDashboard();
}

function updateDashboard() {
    if (!currentPatient) return;
    const p = currentPatient;

    // 1. Profile
    patientProfileEl.innerHTML = `
        <div class="detail-row"><span class="detail-label">Name:</span><span class="detail-value">${p.name}</span></div>
        <div class="detail-row"><span class="detail-label">ID:</span><span class="detail-value">${p.id}</span></div>
        <div class="detail-row"><span class="detail-label">Age:</span><span class="detail-value">${p.age} yrs</span></div>
        <div class="detail-row"><span class="detail-label">Gender:</span><span class="detail-value">${p.gender}</span></div>
    `;

    // 2. Summary
    const nlpSummary = p.nlp_summary ? p.nlp_summary : `"${p.name}, Age: ${p.age}"`;
    patientSummaryEl.innerHTML = `<strong>NLP Summary:</strong> ${nlpSummary}`;
    
    const mapToBadges = (arr, colorClass) => arr.map(item => `<span class="badge ${colorClass}">${item}</span>`).join('');
    
    medicalDetailsEl.innerHTML = `
        <div style="margin-bottom: 1rem;">
            <div style="margin-bottom: 0.25rem; font-size: 0.85rem; color: var(--text-muted);">Allergies</div>
            ${p.allergies[0] !== "None" && p.allergies.length > 0 ? mapToBadges(p.allergies, 'badge-red') : '<span class="badge badge-gray">None</span>'}
        </div>
        <div style="margin-bottom: 1rem;">
            <div style="margin-bottom: 0.25rem; font-size: 0.85rem; color: var(--text-muted);">Frequent Problems</div>
            ${p.frequentProblems[0] !== "None" && p.frequentProblems.length > 0 ? mapToBadges(p.frequentProblems, 'badge-gold') : '<span class="badge badge-gray">None</span>'}
        </div>
        <div style="margin-bottom: 1rem;">
            <div style="margin-bottom: 0.25rem; font-size: 0.85rem; color: var(--text-muted);">Current Medications</div>
            ${p.medications[0] !== "None" && p.medications.length > 0 ? mapToBadges(p.medications, 'badge-blue') : '<span class="badge badge-gray">None</span>'}
        </div>
        <div>
            <div style="margin-bottom: 0.25rem; font-size: 0.85rem; color: var(--text-muted);">Past Surgeries</div>
            ${p.surgeries[0] !== "None" && p.surgeries.length > 0 ? mapToBadges(p.surgeries, 'badge-gray') : '<span class="badge badge-gray">None</span>'}
        </div>
    `;

    // 3. Encounters
    if (p.encounters && p.encounters.length > 0) {
        recentEncountersEl.innerHTML = p.encounters.map(enc => `
            <div class="encounter-item">
                <div class="encounter-date">${enc.date}</div>
                <div style="font-weight: 500; margin-bottom: 0.25rem;">${enc.reason}</div>
                <div style="font-size: 0.85rem; color: var(--text-muted);">${enc.notes}</div>
            </div>
        `).join('');
    } else {
        recentEncountersEl.innerHTML = '<div style="color: var(--text-muted);">No recent encounters found.</div>';
    }

    // 4. AI Recommendations Engine
    generateRecommendations(p);
}

function generateRecommendations(p) {
    const recs = [];
    
    // Rule-based recommendation engine
    if (p.allergies.includes('Penicillin') || p.allergies.includes('Latex')) {
        recs.push("<strong>CRITICAL:</strong> Ensure allergy bands are active. Avoid prescribing Beta-lactam antibiotics or using latex gloves.");
    }
    
    if (p.frequentProblems.includes('Migraine')) {
        recs.push("Consider allergy testing; monitor migraine frequency and advise maintaining a trigger log.");
    }
    
    if (p.frequentProblems.includes('Hypertension')) {
        recs.push("Monitor blood pressure. Review salt intake and current dosage of anti-hypertensive meds.");
    }

    if (p.frequentProblems.includes('Asthma')) {
        recs.push("Check peak flow meter readings. Ask if inhaler usage has increased recently.");
    }

    if (p.age >= 60) {
        recs.push("Routine check: Recommend bone density scan and updated vaccination schedule (e.g., Pneumococcal).");
    }

    // Default if healthy
    if (recs.length === 0) {
        recs.push("Patient file shows no immediate flags. Proceed with standard general checkup.");
    }

    recommendationListEl.innerHTML = recs.map(r => `
        <li>
            <i data-lucide="check-circle" class="rec-icon"></i>
            <div>${r}</div>
        </li>
    `).join('');
    
    // Re-initialize icons for new DOM elements
    lucide.createIcons();
}

// --- Event Listeners ---
searchInput.addEventListener('input', (e) => {
    renderPatientList(e.target.value);
});

addPatientBtn.addEventListener('click', () => {
    patientModal.classList.add('active');
});

closeModalBtn.addEventListener('click', () => {
    patientModal.classList.remove('active');
});

addPatientForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const newId = `P-${1000 + patients.length + 1}`;
    
    const splitStr = (str) => str ? str.split(',').map(s => s.trim()) : ["None"];

    const newPatient = {
        id: newId,
        name: document.getElementById('newName').value,
        age: parseInt(document.getElementById('newAge').value),
        gender: document.getElementById('newGender').value,
        allergies: splitStr(document.getElementById('newAllergies').value),
        frequentProblems: splitStr(document.getElementById('newProblems').value),
        medications: splitStr(document.getElementById('newMedications').value),
        surgeries: splitStr(document.getElementById('newSurgeries').value),
        encounters: []
    };

    try {
        const response = await fetch('/api/patients', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(newPatient)
        });
        
        if (response.ok) {
            const savedPatient = await response.json();
            patients.push(savedPatient);
            
            // Reset and close
            addPatientForm.reset();
            patientModal.classList.remove('active');
            
            // Update view
            searchInput.value = '';
            renderPatientList();
            selectPatient(savedPatient.id);
        } else {
            console.error("Failed to save patient to backend");
        }
    } catch (error) {
        console.error("Error saving patient:", error);
    }
});

// Initialize
loadPatients();
