document.addEventListener("DOMContentLoaded", function(event) {
    runScriptFullOverview('cmi', environment);
    runScriptFullOverview('ais', environment);
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
                r += "<br/>";
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

    if (app == "cmi") {
        table = (env == "prod") ? document.querySelector("#dataTableCmiProd") : document.querySelector("#dataTableCmiTest");
    } else {
        table = (env == "prod") ? document.querySelector("#dataTableAisProd") : document.querySelector("#dataTableAisTest");
    }

    const tableHead = document.createElement("thead");
    table.appendChild(tableHead);

    const tableBody = document.createElement("tbody");
    table.appendChild(tableBody);

    const tableHeadTr = document.createElement("tr");
    tableHead.appendChild(tableHeadTr);

    // Alle Header wie gehabt...
    const headers = [
        { text: "Name" }, { text: "Mandant" }, { text: "Release" }, { text: "Host" },
        { text: "Install path" }, { text: "Service Name" }, { text: "Service User", minwidth: true },
        { text: "License Server/Port", minwidth: true }, { text: "Mobile Client", minwidth: true },
        { text: "Mobile Apps", minwidth: true }, { text: "Ueberweisungen", minwidth: true },
        { text: "Mügi", minwidth: true }, { text: "Objekt Loader / Remoting", minwidth: true },
        { text: "Webconsole" }, { text: "Owin Server", minwidth: true }, { text: "STS3", minwidth: true },
        { text: "Jobs", minwidth: true }, { text: "DB Host" }, { text: "DB Name" }
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

        // Name
        const nameCell = document.createElement("td");
        nameCell.classList.add(tdclass);
        if (item.namefull?._text) {
            nameCell.innerHTML = "<b>" + escapeHtml(item.namefull._text) + "</b>";
        } else {
            nameCell.textContent = "";
        }
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        // Mandant
        const mandCell = document.createElement("td");
        mandCell.classList.add(tdclass);
        mandCell.textContent = item.mand?._text ?? "";
        mandCell.setAttribute('scope', 'row');
        row.appendChild(mandCell);

        // Release
        const versionCell = document.createElement("td");
        versionCell.classList.add(tdclass);
        versionCell.textContent = item.app?.releaseversion?._text ?? "";
        row.appendChild(versionCell);

        // Host
        const hostCell = document.createElement("td");
        hostCell.classList.add(tdclass);
        hostCell.textContent = item.app?.host?._text ?? "";
        row.appendChild(hostCell);

        // Install path
        const installpathCell = document.createElement("td");
        installpathCell.classList.add(tdclass);
        installpathCell.textContent = item.app?.installpath?._text ?? "";
        row.appendChild(installpathCell);

        // Service Name
        const servicenameCell = document.createElement("td");
        servicenameCell.classList.add(tdclass);
        servicenameCell.textContent = item.app?.servicename?._text ?? "";
        row.appendChild(servicenameCell);

        // Service User
        const serviceuserCell = document.createElement("td");
        serviceuserCell.classList.add(tdclass, tdurlminwidth);
        serviceuserCell.textContent = item.app?.serviceuser?._text ?? "";
        row.appendChild(serviceuserCell);

        // License Server/Port
        const licenseCell = document.createElement("td");
        licenseCell.classList.add(tdclass, tdurlminwidth);
        if (item.licenseserver?.server?._text && item.licenseserver?.port?._text) {
            licenseCell.textContent = item.licenseserver.server._text + ":" + item.licenseserver.port._text;
        } else {
            licenseCell.textContent = "";
        }
        row.appendChild(licenseCell);

        // Mobile Client
        const mobilefirstCell = document.createElement("td");
        mobilefirstCell.classList.add(tdclass, tdurlminwidth);
        if (item.mobilefirst?._text) {
            let link = document.createElement("a");
            link.href = item.mobilefirst._text;
            link.textContent = item.mobilefirst._text;
            link.target = "_blank";
            mobilefirstCell.appendChild(link);
        }
        row.appendChild(mobilefirstCell);

        // Mobile Apps
        const mobileCell = document.createElement("td");
        mobileCell.classList.add(tdclass, tdurlminwidth);
        if (
            item.mand?._text &&
            !(item.namefull?._text?.includes('AIS') && item.namefull?._text !== "AIS Benutzungsverwaltung")
        ) {
            let m = escapeHtml(item.mand._text);
            mobileCell.innerHTML = m + "<br/>"
                + "https://mobile.cmiaxioma.ch/sitzungsvorbereitung/" + m + "<br/>"
                + "https://mobile.cmiaxioma.ch/dossierbrowser/" + m + "<br/>"
                + "https://mobile.cmiaxioma.ch/zusammenarbeitdritte/" + m;
        } else {
            mobileCell.textContent = "";
        }
        row.appendChild(mobileCell);

        // Ueberweisungen
        const ueberweisungCell = document.createElement("td");
        ueberweisungCell.classList.add(tdclass, tdurlminwidth);
        if (item.ueberweisung?.port?._text && item.app?.host?._text) {
            ueberweisungCell.innerHTML = "<b>http://" + escapeHtml(item.app.host._text)
                + ":" + escapeHtml(item.ueberweisung.port._text) + "/</b>";
            ueberweisungCell.innerHTML += getSubLevels(item.ueberweisung.url);
        } else {
            ueberweisungCell.textContent = "";
        }
        row.appendChild(ueberweisungCell);

        // Mügi
        const muegiCell = document.createElement("td");
        muegiCell.classList.add(tdclass, tdurlminwidth);
        if (item.muegi?.url) {
            muegiCell.innerHTML = getSubLevels(item.muegi.url);
        } else {
            muegiCell.textContent = "";
        }
        row.appendChild(muegiCell);

        // Objekt Loader / Remoting
        const objloaderCell = document.createElement("td");
        objloaderCell.classList.add(tdclass, tdurlminwidth);
        if (item.objektloader?.port?._text) {
            objloaderCell.textContent = "Port: " + item.objektloader.port._text;
        } else {
            objloaderCell.textContent = "";
        }
        row.appendChild(objloaderCell);

        // Webconsole
        const webconsoleCell = document.createElement("td");
        webconsoleCell.classList.add(tdclass);
        if (item.webconsole?.port?._text) {
            webconsoleCell.textContent = "Port: " + item.webconsole.port._text;
        } else {
            webconsoleCell.textContent = "";
        }
        row.appendChild(webconsoleCell);

        // Owin Server
        const owinCell = document.createElement("td");
        owinCell.classList.add(tdclass, tdurlminwidth);
        if (item.owinserver?.port?.private?._text || item.owinserver?.port?.public?._text) {
            let out = "";
            if (item.owinserver?.port?.private?._text) {
                out += "Port private: " + escapeHtml(item.owinserver.port.private._text) + "<br/>";
            }
            if (item.owinserver?.port?.public?._text) {
                out += "Port public: " + escapeHtml(item.owinserver.port.public._text);
            }
            owinCell.innerHTML = out;
        } else {
            owinCell.textContent = "";
        }
        row.appendChild(owinCell);

        // STS3
        const stsCell = document.createElement("td");
        stsCell.classList.add(tdclass, tdurlminwidth);
        if (item.sts?.desktopclient?._text || item.sts?.ea?._text) {
            let out = "";
            if (item.sts.desktopclient?._text) {
                out += "DesktopClient: " + escapeHtml(item.sts.desktopclient._text) + "<br/>";
            }
            if (item.sts.ea?._text) {
                out += "Entra App: " + escapeHtml(item.sts.ea._text);
            }
            stsCell.innerHTML = out;
        } else {
            stsCell.textContent = "";
        }
        row.appendChild(stsCell);

        // Jobs
        const jobsCell = document.createElement("td");
        jobsCell.classList.add(tdclass, tdurlminwidth);
        let jobsOutput = "";
        if (item.jobs?.adrsync?._text) {
            jobsOutput += "<b>Adr. Sync: </b>" + escapeHtml(item.jobs.adrsync._text) + "<br/>";
        }
        if (item.jobs?.fulltextoptimize?._text) {
            jobsOutput += "<b>Fulltext Index Optimize: </b>" + escapeHtml(item.jobs.fulltextoptimize._text) + "<br/>";
        }
        if (item.jobs?.fulltextrebuild?._text) {
            jobsOutput += "<b>Fulltext Index Rebuild: </b>" + escapeHtml(item.jobs.fulltextrebuild._text);
        }
        jobsCell.innerHTML = jobsOutput;
        row.appendChild(jobsCell);

        // DB Host
        const dbhostCell = document.createElement("td");
        dbhostCell.classList.add(tdclass);
        dbhostCell.textContent = item.database?.host?._text ?? "";
        row.appendChild(dbhostCell);

        // DB Name
        const dbnameCell = document.createElement("td");
        dbnameCell.classList.add(tdclass);
        dbnameCell.textContent = item.database?.name?._text ?? "";
        row.appendChild(dbnameCell);

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
        cell.innerHTML = cell.innerHTML.replace(/<br\s*\/?>/gi, '\n');
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
    const ws = wb.Sheets["Tabelle"];

    // Für alle Zellen: Wenn \n enthalten, wrapText aktivieren
    for (const cellAddress in ws) {
        if (!ws.hasOwnProperty(cellAddress)) continue;
        if (cellAddress[0] === '!') continue; // Meta-Daten überspringen

        const cell = ws[cellAddress];
        if (typeof cell.v === "string" && cell.v.includes('\n')) {
            cell.s = cell.s || {};
            cell.s.alignment = cell.s.alignment || {};
            cell.s.alignment.wrapText = true;
        }
    }

    // Schreibe das File mit Styles
    XLSX.writeFile(wb, filename, {cellStyles: true});
}



async function runScriptFullOverview(app, env) {
    const tableRaw = document.getElementById("tableRaw");
    tableRaw.textContent = `Running script with: App=${app}, Env=${env}...\n`;

    try {
        const response = await fetch('/run-script-fulloverview', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ app, env })
        });

        if (response.ok) {
            const result = await response.json();
            tableRaw.textContent = "";
            populateTable(result.Data || [], app, env);
        } else {
            let error;
            try {
                error = await response.json();
            } catch {
                error = { error: "Unbekannter Fehler" };
            }
            tableRaw.textContent += `Error: ${error.error}`;
        }
    } catch (error) {
        tableRaw.textContent += `Error: ${error.message}`;
    }
}
