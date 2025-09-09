document.addEventListener("DOMContentLoaded", function (event) {
    runScriptJobsOverview();
});

// ---------------- Helpers ---------------------------------------------------

function escapeHtml(unsafe) {
    if (!unsafe) return "";
    return String(unsafe)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function toArray(x) {
    if (!x) return [];
    return Array.isArray(x) ? x : [x];
}

function getText(v) {
    if (v == null) return "";
    if (typeof v === "string" || typeof v === "number") return String(v);
    if (typeof v === "object" && "_text" in v) return String(v._text ?? "");
    return "";
}

function collectJobNames(data) {
    const set = new Set();
    for (const item of data) {
        for (const j of toArray(item?.jobs?.job)) {
            const name = getText(j?.name).trim();
            if (name) set.add(name);
        }
    }
    return Array.from(set).sort((a, b) =>
        a.localeCompare(b, "de", { sensitivity: "base", numeric: true })
    );
}

function computeJobCounts(data) {
    const map = new Map();
    for (const item of data) {
        for (const j of toArray(item?.jobs?.job)) {
            const name = getText(j?.name).trim();
            if (!name) continue;
            map.set(name, (map.get(name) || 0) + 1);
        }
    }
    return map;
}

// ---------------- State -----------------------------------------------------

const JOBS_STATE = {
    data: [],
    jobNames: [],
    selected: null,
};

// ---------------- UI: Job-Selector -----------------------------------------

function ensureJobSelectorContainer() {
    let ctr = document.getElementById("jobSelector");
    if (!ctr) {
        // direkt NACH #tableRaw einfügen (existiert schon in deinem HTML)
        const tableRawEl = document.getElementById("tableRaw");
        ctr = document.createElement("div");
        ctr.id = "jobSelector";
        ctr.className = "mb-2";
        if (tableRawEl) {
            tableRawEl.insertAdjacentElement("afterend", ctr);
        } else {
            // Fallback: vor die Tabelle setzen
            const tbl = document.getElementById("dataTableCmiJobs");
            tbl?.parentElement?.insertAdjacentElement("beforebegin", ctr);
        }
    }
    return ctr;
}

function renderJobSelector(names) {
    const ctr = ensureJobSelectorContainer();
    ctr.innerHTML = ""; // reset

    if (!names.length) {
        ctr.textContent = "Keine Jobs gefunden.";
        return;
    }

    const counts = computeJobCounts(JOBS_STATE.data);

    // Vertikale Anordnung
    const form = document.createElement("div");
    // Optional hübsch: form.className = "d-flex flex-column"; // falls Bootstrap 4/5
    form.setAttribute("role", "radiogroup");

    names.forEach((name, idx) => {
        const id = `jobradio-${idx}`;

        // Kein "form-check-inline" -> damit jede Option in eigener Zeile
        const wrapper = document.createElement("div");
        wrapper.className = "form-check mb-1";

        const input = document.createElement("input");
        input.className = "form-check-input";
        input.type = "radio";
        input.name = "jobName";
        input.id = id;
        input.value = name;
        input.checked = JOBS_STATE.selected ? (JOBS_STATE.selected === name) : (idx === 0);
        input.addEventListener("change", (e) => {
            if (e.target.checked) {
                JOBS_STATE.selected = e.target.value;
                renderTableForSelectedJob();
            }
        });

        const label = document.createElement("label");
        label.className = "form-check-label";
        label.setAttribute("for", id);
        const count = counts.get(name) || 0;
        label.textContent = `${name} (${count})`;

        wrapper.appendChild(input);
        wrapper.appendChild(label);
        form.appendChild(wrapper);
    });

    ctr.appendChild(form);

    if (!JOBS_STATE.selected) {
        JOBS_STATE.selected = names[0];
    }
}


// ---------------- Tabelle: nur 1 Job ---------------------------------------

function renderTableForSelectedJob() {
    const table = document.querySelector("#dataTableCmiJobs");
    if (!table) {
        console.error("#dataTableCmiJobs not found");
        return;
    }
    table.innerHTML = "";

    const thead = document.createElement("thead");
    const tbody = document.createElement("tbody");
    table.appendChild(thead);
    table.appendChild(tbody);

    // Header: Name | Mandant | Job Name | Days | Time | Type
    const trh = document.createElement("tr");
    ["Name", "Mandant", "Job Name", "Days", "Time", "Type"].forEach((h) => {
        const th = document.createElement("th");
        th.classList.add("py-1");
        th.textContent = h;
        trh.appendChild(th);
    });
    thead.appendChild(trh);

    const jobName = JOBS_STATE.selected;
    if (!jobName) return;

    // Rows sammeln
    const rows = [];
    for (const item of JOBS_STATE.data) {
        const mandname = getText(item?.namefull).trim();
        const mand = getText(item?.mand).trim();
        const jobs = toArray(item?.jobs?.job).filter(j => getText(j?.name).trim() === jobName);
        for (const j of jobs) {
            rows.push({
                mandname,
                mand,
                jobname: jobName,
                days: getText(j?.days),
                time: getText(j?.time),
                type: getText(j?.type),
            });
        }
    }

    // Nur Mandanten mit diesem Job (rows ist dann leer, wenn keiner passt)
    // Sortierung: Mandant, dann Time
    rows.sort((a, b) => {
        const m = a.mand.localeCompare(b.mand, "de", { sensitivity: "base", numeric: true });
        if (m !== 0) return m;
        return a.time.localeCompare(b.time, "de", { numeric: true });
    });

    // Rendern
    for (const r of rows) {
        const tr = document.createElement("tr");
        const cells = [
            escapeHtml(r.mandname),
            escapeHtml(r.mand),
            escapeHtml(r.jobname),
            escapeHtml(r.days),
            escapeHtml(r.time),
            escapeHtml(r.type),
        ];
        for (const html of cells) {
            const td = document.createElement("td");
            td.classList.add("py-1");
            td.textContent = html; // Inhalte sind plain text
            tr.appendChild(td);
        }
        tbody.appendChild(tr);
    }

    // Hinweis, wenn keine Zeilen
    if (!rows.length) {
        const tr = document.createElement("tr");
        const td = document.createElement("td");
        td.colSpan = 5;
        td.className = "py-1 text-muted";
        td.textContent = "Keine Einträge für diesen Job.";
        tr.appendChild(td);
        tbody.appendChild(tr);
    }
}

// ---------------- Fetch + Init ---------------------------------------------

async function runScriptJobsOverview() {
    const tableRaw = document.getElementById("tableRaw");
    if (tableRaw) tableRaw.textContent = `Running script\n`;

    try {
        const response = await fetch("/run-script-fulloverview-jobs", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: "{}",
        });

        if (response.ok) {
            const result = await response.json();
            if (tableRaw) tableRaw.textContent = "";
            const arr = Array.isArray(result.Data) ? result.Data : (result.Data ? [result.Data] : []);

            JOBS_STATE.data = arr;
            JOBS_STATE.jobNames = collectJobNames(arr);

            renderJobSelector(JOBS_STATE.jobNames);
            renderTableForSelectedJob();
        } else {
            const error = await response.json();
            if (tableRaw) tableRaw.textContent += `Error: ${error.error}`;
        }
    } catch (error) {
        if (tableRaw) tableRaw.textContent += `Error: ${error.message}`;
    }
}
