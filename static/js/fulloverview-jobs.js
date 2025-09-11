document.addEventListener("DOMContentLoaded", function (event) {
    runScriptJobsOverview();
});


// ---------------- Helpers ---------------------------------------------------

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

function makeJobKey(t, name) {
  t = (t || "").trim();
  name = (name || "").trim();
  return t ? `${t} | ${name}` : name;   // wenn kein type vorhanden, nur name
}

function splitJobKey(key) {
  const i = key.indexOf("|");
  if (i === -1) return ["", key.trim()];
  return [key.slice(0, i).trim(), key.slice(i + 1).trim()];
}

function collectJobNames(data) {
  const set = new Set();
  for (const item of data) {
    for (const j of toArray(item?.jobs?.job)) {
      const t = getText(j?.type).trim();
      const name = getText(j?.name).trim();
      if (name) set.add(makeJobKey(t, name));
    }
  }

  const collator = new Intl.Collator('de', { sensitivity: 'base', numeric: true });

  return Array.from(set).sort((a, b) => {
    const [ta, na] = splitJobKey(a);
    const [tb, nb] = splitJobKey(b);
    const first = collator.compare(ta, tb);
    return first !== 0 ? first : collator.compare(na, nb);
  });
}

function computeJobCounts(data) {
  const map = new Map();
  for (const item of data) {
    for (const j of toArray(item?.jobs?.job)) {
      const t = getText(j?.type).trim();
      const name = getText(j?.name).trim();
      if (!name) continue;
      const key = makeJobKey(t, name);
      map.set(key, (map.get(key) || 0) + 1);
    }
  }
  return map;
}

function cloneTableWithLinebreaks(table) {
    // Tabelle klonen, damit die Seite unverändert bleibt
    const clone = table.cloneNode(true);
    // Alle Zellen durchgehen
    clone.querySelectorAll('td,th').forEach(cell => {
        // Ersetze <br> durch \n im Inhalt
        cell.innerHTML = cell.innerHTML.replace(/<br\s*\/?>/gi, ' | ');
    });
    return clone;
}

function downloadTableAsXlsx(tableId, filename) {
    const table = document.getElementById(tableId);
    if (!table) {
        alert("Tabelle nicht gefunden!");
        return;
    }
    const clone = cloneTableWithLinebreaks(table);
    const wb = XLSX.utils.table_to_book(clone, {sheet: "Tabelle"});
    XLSX.writeFile(wb, filename);
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
    form.setAttribute("role", "radiogroup");

    names.forEach((name, idx) => {
        const id = `jobradio-${idx}`;
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

  const trh = document.createElement("tr");
  ["Name", "Mandant", "Job Name", "Days", "Time", "Type"].forEach((h) => {
    const th = document.createElement("th");
    th.classList.add("py-1");
    th.textContent = h;
    trh.appendChild(th);
  });
  thead.appendChild(trh);

  const jobKey = JOBS_STATE.selected;
  if (!jobKey) return;
  const [selType, selName] = splitJobKey(jobKey);

  const rows = [];
  for (const item of JOBS_STATE.data) {
    const mandname = getText(item?.namefull).trim();
    const mand = getText(item?.mand).trim();
    const jobs = toArray(item?.jobs?.job).filter(j =>
      getText(j?.name).trim() === selName &&
      getText(j?.type).trim() === selType
    );
    for (const j of jobs) {
      rows.push({
        mandname,
        mand,
        jobname: selName,
        days: getText(j?.days),
        time: getText(j?.time),
        type: getText(j?.type),
      });
    }
  }

  rows.sort((a, b) => {
    const m = a.mand.localeCompare(b.mand, "de", { sensitivity: "base", numeric: true });
    if (m !== 0) return m;
    return a.time.localeCompare(b.time, "de", { numeric: true });
  });

  for (const r of rows) {
    const tr = document.createElement("tr");
    const cells = [r.mandname, r.mand, r.jobname, r.days, r.time, r.type];
    for (const txt of cells) {
      const td = document.createElement("td");
      td.classList.add("py-1");
      td.textContent = txt; // textContent ist sicher; escapeHtml hier nicht nötig
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }

  if (!rows.length) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 6; // <-- du hast 6 Spalten
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
