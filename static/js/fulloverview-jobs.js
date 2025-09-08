document.addEventListener("DOMContentLoaded", function(event) {
    runScriptJobsOverview();
});

// Hilfsfunktion für sicheres Escapen von HTML (verhindert XSS)
function escapeHtml(unsafe) {
    if (!unsafe) return "";
    return String(unsafe)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function getSubLevels(u) {
    if (u) {
        if (typeof u._text === "string") {
            return escapeHtml(u._text);
        } else if (Array.isArray(u)) {
            let r = "";
            for (let i = 0; i < u.length; i++) {
                r += "<br>";
                if (u[i].name === undefined) {
                    r += escapeHtml(u[i]._text);
                } else {
                    r += escapeHtml(u[i].name) + ": " + escapeHtml(u[i]._text);
                }
            }
            return r || "";
        }
    }
    return "";
}

// in Array verwandeln (auch wenn 1 Objekt oder undefined)
function toArray(x) {
    if (!x) return [];
    return Array.isArray(x) ? x : [x];
}

// _text sauber lesen (oder string/number direkt)
function getText(v) {
    if (v == null) return "";
    if (typeof v === "string" || typeof v === "number") return String(v);
    if (typeof v === "object" && "_text" in v) return String(v._text ?? "");
    return "";
}

// alle Job-Namen über die Daten sammeln (einzigartig + sortiert)
function collectJobNames(data) {
    const set = new Set();
    for (const item of data) {
        for (const j of toArray(item?.jobs?.job)) {
            const name = getText(j?.name).trim();
            if (name) set.add(name);
        }
    }
    // Deutsch-freundlich sortieren, Groß/Kleinschreibung ignorieren
    return Array.from(set).sort((a, b) =>
        a.localeCompare(b, "de", { sensitivity: "base", numeric: true })
    );
}

// --- Tabelle ---------------------------------------------------------------

function populateTable(data) {
    const tdclass = "py-1";
    const tdurlminwidth = "url-minwidth"; // falls du das für min-width nutzt
    const table = document.querySelector("#dataTableCmiJobs");

    // defensiv leeren, falls mehrfach aufgerufen
    table.innerHTML = "";

    // 1) dynamische Header bestimmen
    const jobNames = collectJobNames(data);

    const tableHead = document.createElement("thead");
    const tableBody = document.createElement("tbody");
    table.appendChild(tableHead);
    table.appendChild(tableBody);

    const tableHeadTr = document.createElement("tr");
    tableHead.appendChild(tableHeadTr);

    const headers = [{ text: "Mandant" }, ...jobNames.map(n => ({ text: n, minwidth: true }))];

    for (const h of headers) {
        const th = document.createElement("th");
        th.classList.add(tdclass);
        if (h.minwidth) th.classList.add(tdurlminwidth);
        th.textContent = h.text;          // Header selbst nicht als HTML
        th.title = h.text;                // Tooltip bei langen Namen
        tableHeadTr.appendChild(th);
    }

    // 2) Zeilen befüllen
    data.forEach(item => {
        const row = document.createElement("tr");

        // Mandant
        const mandCell = document.createElement("td");
        mandCell.classList.add(tdclass);
        mandCell.textContent = getText(item?.mand);
        mandCell.setAttribute("scope", "row");
        row.appendChild(mandCell);

        // Jobs des Mandanten nach Name gruppieren -> mehrere Einträge pro Name via <br>
        const jobsByName = new Map();
        for (const j of toArray(item?.jobs?.job)) {
            const name = getText(j?.name).trim();
            if (!name) continue;

            const parts = [
                getText(j?.days),
                getText(j?.time),
                (function () {
                    const t = getText(j?.type);
                    return t ? `(${t})` : "";
                })()
            ].map(escapeHtml).filter(Boolean);

            const line = parts.join(" ");
            if (!line) continue;

            const existing = jobsByName.get(name);
            jobsByName.set(name, existing ? `${existing}<br>${line}` : line);
        }

        // Für jede dynamische Job-Spalte die passende Zelle rendern
        for (const name of jobNames) {
            const td = document.createElement("td");
            td.classList.add(tdclass);
            // Wir haben die Inhalte bereits escaped; <br> bleibt absichtlich HTML
            const html = jobsByName.get(name) || "";
            td.innerHTML = html;
            row.appendChild(td);
        }

        tableBody.appendChild(row);
    });
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


async function runScriptJobsOverview() {
    const tableRaw = document.getElementById("tableRaw");
    tableRaw.textContent = `Running script\n`;

    try {
        const response = await fetch('/run-script-fulloverview-jobs', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: '{}'
        });

        if (response.ok) {
            const result = await response.json();
            tableRaw.textContent = "";
            populateTable(result.Data || []);
        } else {
            const error = await response.json();
            tableRaw.textContent += `Error: ${error.error}`;
        }
    } catch (error) {
        tableRaw.textContent += `Error: ${error.message}`;
    }
}
