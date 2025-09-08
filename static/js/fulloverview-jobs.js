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

function populateTable(data, app, env) {
    const tdclass = "py-1";
    const tdurlminwidth = "url-minwidth";
    let table;

    table = document.querySelector("#dataTableCmiJobs");

    const tableHead = document.createElement("thead");
    table.appendChild(tableHead);

    const tableBody = document.createElement("tbody");
    table.appendChild(tableBody);

    const tableHeadTr = document.createElement("tr");
    tableHead.appendChild(tableHeadTr);

    const headers = [
        { text: "Mandant" }, 
    ];
    for (const h of headers) {
        const th = document.createElement("th");
        th.classList.add(tdclass);
        if (h.minwidth) th.classList.add(tdurlminwidth);
        th.textContent = h.text;
        tableHeadTr.appendChild(th);
    }

    data.forEach(item => {
        const row = document.createElement("tr");

        // Mandant
        const mandCell = document.createElement("td");
        mandCell.classList.add(tdclass);
        mandCell.textContent = item.mand?._text ?? "";
        mandCell.setAttribute('scope', 'row');
        row.appendChild(mandCell);


        // Row anfügen
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
        const response = await fetch('/run-script-fulloverviewjobs', {
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
