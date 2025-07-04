document.addEventListener("DOMContentLoaded", function(event) {
    runScriptFullOverview('cmi', 'prod', 'relay-true');
    runScriptFullOverview('ais', 'prod', 'relay-true');
    runScriptFullOverview('cmi', 'test', 'relay-false');
    runScriptFullOverview('ais', 'test', 'relay-false');
});

function getSubLevels(u) {
    if (u) { // only if u is not undefined (= there are urls)
        if (typeof u._text === "string") { // in case only one muegi url
            return u._text;
        } else {
            var r = "";
                for (var i = 0; i < u.length; i++) {
                    r += "<br/>";
                    if (u[i].name === undefined) {
                        r += u[i]._text;
                    } else {
                        r += u[i].name+": "+u[i]._text;
                    }
                }
            return r;
        }
    }
}

function populateTable(data, app, env, relay_handling) {
    const tdclass = "py-1";
    const tdurlminwidth = "url-minwidth";
    
    var table;
    
    if (app == "cmi") {
        if (env == "prod") {
            table = document.querySelector("#dataTableCmiProd");
        } else {
            table = document.querySelector("#dataTableCmiTest");
        }
    } else {
        if (env == "prod") {
            table = document.querySelector("#dataTableAisProd");
        } else {
            table = document.querySelector("#dataTableAisTest");
        }
    }
    
    const tableHead = document.createElement("thead");
    table.appendChild(tableHead);
    
    const tableBody = document.createElement("tbody");
    table.appendChild(tableBody);
    
    
    const tableHeadTr = document.createElement("tr");
    tableHead.appendChild(tableHeadTr);
    
    const nameCellHeader = document.createElement("th");
    nameCellHeader.classList.add(tdclass);
    nameCellHeader.textContent = "Name";
    tableHeadTr.appendChild(nameCellHeader);
    
    const mandCellHeader = document.createElement("th");
    mandCellHeader.classList.add(tdclass);
    mandCellHeader.textContent = "Mandant";
    tableHeadTr.appendChild(mandCellHeader);
    
    const versionCellHeader = document.createElement("th");
    versionCellHeader.classList.add(tdclass);
    versionCellHeader.textContent = "Release";
    tableHeadTr.appendChild(versionCellHeader);
    
    const hostCellHeader = document.createElement("th");
    hostCellHeader.classList.add(tdclass);
    hostCellHeader.textContent = "Host";
    tableHeadTr.appendChild(hostCellHeader);
    
    const installpathCellHeader = document.createElement("th");
    installpathCellHeader.classList.add(tdclass);
    installpathCellHeader.textContent = "Install path";
    tableHeadTr.appendChild(installpathCellHeader);
    
    if (relay_handling == 'relay-true') {
    const installpathRelayCellHeader = document.createElement("th");
    installpathRelayCellHeader.classList.add(tdclass);
    installpathRelayCellHeader.textContent = "Relay install path";
    tableHeadTr.appendChild(installpathRelayCellHeader);
    }
    
    const servicenameCellHeader = document.createElement("th");
    servicenameCellHeader.classList.add(tdclass);
    servicenameCellHeader.textContent = "Service Name";
    tableHeadTr.appendChild(servicenameCellHeader);
    
    const serviceuserCellHeader = document.createElement("th");
    serviceuserCellHeader.classList.add(tdclass);
    serviceuserCellHeader.classList.add(tdurlminwidth);
    serviceuserCellHeader.textContent = "Service User";
    tableHeadTr.appendChild(serviceuserCellHeader);
    
    if (relay_handling == 'relay-true') {
    const servicenamerelayCellHeader = document.createElement("th");
    servicenamerelayCellHeader.classList.add(tdclass);
    servicenamerelayCellHeader.classList.add(tdurlminwidth);
    servicenamerelayCellHeader.textContent = "Service Name Relay";
    tableHeadTr.appendChild(servicenamerelayCellHeader);
    
    const serviceuserrelayCellHeader = document.createElement("th");
    serviceuserrelayCellHeader.classList.add(tdclass);
    serviceuserrelayCellHeader.classList.add(tdurlminwidth);
    serviceuserrelayCellHeader.textContent = "Service User Relay";
    tableHeadTr.appendChild(serviceuserrelayCellHeader);
    }
    
    const licenseCellHeader = document.createElement("th");
    licenseCellHeader.classList.add(tdclass);
    licenseCellHeader.classList.add(tdurlminwidth);
    licenseCellHeader.textContent = "License Server/Port";
    tableHeadTr.appendChild(licenseCellHeader);
    
    const mobileCellHeader = document.createElement("th");
    mobileCellHeader.classList.add(tdclass);
    mobileCellHeader.classList.add(tdurlminwidth);
    mobileCellHeader.textContent = "Mobile Client";
    tableHeadTr.appendChild(mobileCellHeader);
    
    const mobileAppsCellHeader = document.createElement("th");
    mobileAppsCellHeader.classList.add(tdclass);
    mobileAppsCellHeader.classList.add(tdurlminwidth);
    mobileAppsCellHeader.textContent = "Mobile Apps";
    tableHeadTr.appendChild(mobileAppsCellHeader);
    
    const ueberweisungCellHeader = document.createElement("th");
    ueberweisungCellHeader.classList.add(tdclass);
    ueberweisungCellHeader.classList.add(tdurlminwidth);
    ueberweisungCellHeader.textContent = "Ueberweisungen";
    tableHeadTr.appendChild(ueberweisungCellHeader);
    
    const muegiCellHeader = document.createElement("th");
    muegiCellHeader.classList.add(tdclass);
    muegiCellHeader.classList.add(tdurlminwidth);
    muegiCellHeader.textContent = "Mügi";
    tableHeadTr.appendChild(muegiCellHeader);
    
    const objloaderCellHeader = document.createElement("th");
    objloaderCellHeader.classList.add(tdclass);
    objloaderCellHeader.classList.add(tdurlminwidth);
    objloaderCellHeader.textContent = "Objekt Loader / Remoting";
    tableHeadTr.appendChild(objloaderCellHeader);
    
    const webconsoleCellHeader = document.createElement("th");
    webconsoleCellHeader.classList.add(tdclass);
    webconsoleCellHeader.textContent = "Webconsole";
    tableHeadTr.appendChild(webconsoleCellHeader);
    
    const owinCellHeader = document.createElement("th");
    owinCellHeader.classList.add(tdclass);
    owinCellHeader.classList.add(tdurlminwidth);
    owinCellHeader.textContent = "Owin Server";
    tableHeadTr.appendChild(owinCellHeader);
    
    const stsCellHeader = document.createElement("th");
    stsCellHeader.classList.add(tdclass);
    stsCellHeader.classList.add(tdurlminwidth);
    stsCellHeader.textContent = "STS3";
    tableHeadTr.appendChild(stsCellHeader);
    
    const jobsCellHeader = document.createElement("th");
    jobsCellHeader.classList.add(tdclass);
    jobsCellHeader.classList.add(tdurlminwidth);
    jobsCellHeader.textContent = "Jobs";
    tableHeadTr.appendChild(jobsCellHeader);
    
    const dbhostCellHeader = document.createElement("th");
    dbhostCellHeader.classList.add(tdclass);
    dbhostCellHeader.textContent = "DB Host";
    tableHeadTr.appendChild(dbhostCellHeader);
    
    const dbnameCellHeader = document.createElement("th");
    dbnameCellHeader.classList.add(tdclass);
    dbnameCellHeader.textContent = "DB Name";
    tableHeadTr.appendChild(dbnameCellHeader);
    
    console.log(data);

    // Loop through JSON data and create rows
    data.forEach(item => {
        const row = document.createElement("tr");

        const nameCell = document.createElement("td");
        nameCell.classList.add(tdclass);
        nameCell.innerHTML = "<b>"+item.namefull._text+"</b>" || "";
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        const mandCell = document.createElement("td");
        mandCell.classList.add(tdclass);
        mandCell.textContent = item.mand._text || "";
        mandCell.setAttribute('scope', 'row');
        row.appendChild(mandCell);

        const versionCell = document.createElement("td");
        versionCell.classList.add(tdclass);
        versionCell.textContent = item.app.releaseversion._text || "";
        row.appendChild(versionCell);

        const hostCell = document.createElement("td");
        hostCell.classList.add(tdclass);
        hostCell.textContent = item.app.host._text || "";
        row.appendChild(hostCell);

        const installpathCell = document.createElement("td");
        installpathCell.classList.add(tdclass);
        installpathCell.textContent = item.app.installpath._text || "";
        row.appendChild(installpathCell);

        if (relay_handling == 'relay-true') {
        const installpathRelayCell = document.createElement("td");
        installpathRelayCell.classList.add(tdclass);
        installpathRelayCell.textContent = item.app.installpathrelay._text || "";
        row.appendChild(installpathRelayCell);
        }

        const servicenameCell = document.createElement("td");
        servicenameCell.classList.add(tdclass);
        servicenameCell.textContent = item.app.servicename._text || "";
        row.appendChild(servicenameCell);

        const serviceuserCell = document.createElement("td");
        serviceuserCell.classList.add(tdclass);
        serviceuserCell.textContent = item.app.serviceuser._text || "";
        row.appendChild(serviceuserCell);
        
        if (relay_handling == 'relay-true') {
        if (item.app.servicenamerelay === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const servicenamerelayCell = document.createElement("td");
            servicenamerelayCell.classList.add(tdclass);
            servicenamerelayCell.textContent = item.app.servicenamerelay._text;
            row.appendChild(servicenamerelayCell);
        }

        if (item.app.serviceuserrelay === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const serviceuserrelayCell = document.createElement("td");
            serviceuserrelayCell.classList.add(tdclass);
            serviceuserrelayCell.textContent = item.app.serviceuserrelay._text;
            row.appendChild(serviceuserrelayCell);
        }
        }

        if (item.licenseserver === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const licenseCell = document.createElement("td");
            licenseCell.classList.add(tdclass);
            licenseCell.textContent = item.licenseserver.server._text+":"+item.licenseserver.port._text;
            row.appendChild(licenseCell);
        }

        if (item.mobilefirst === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const mobilefirstCell = document.createElement("td");
            mobilefirstCell.classList.add(tdclass);
            mobilefirstCell.classList.add(tdurlminwidth);
            let link = document.createElement("a");
            link.href = item.mobilefirst._text;
            link.textContent = item.mobilefirst._text;
            link.target = "_blank";
            mobilefirstCell.appendChild(link);
            row.appendChild(mobilefirstCell);
        }

        if (item.owinserver === undefined || ((item.namefull._text).includes('AIS') && item.namefull._text !== "AIS Benutzungsverwaltung")) {
            row.appendChild(document.createElement("td"));
        } else {
            const mobileCell = document.createElement("td");
            mobileCell.classList.add(tdclass);
            mobileCell.classList.add(tdurlminwidth);
            mobileCell.innerHTML = "https://mobile.cmiaxioma.ch/sitzungsvorbereitung/"+item.mand._text+"<br/>";
            mobileCell.innerHTML += "https://mobile.cmiaxioma.ch/dossierbrowser/"+item.mand._text+"<br/>";
            mobileCell.innerHTML += "https://mobile.cmiaxioma.ch/zusammenarbeitdritte/"+item.mand._text;
            row.appendChild(mobileCell);
        }

        if (item.ueberweisung === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const ueberweisungCell = document.createElement("td");
            ueberweisungCell.classList.add(tdclass);
            ueberweisungCell.classList.add(tdurlminwidth);
            ueberweisungCell.innerHTML = "<b>http://"+item.app.host._text+":"+item.ueberweisung.port._text+"/</b>" || "";
            ueberweisungCell.innerHTML += getSubLevels(item.ueberweisung.url) || "";
            row.appendChild(ueberweisungCell);
        }

        if (item.muegi === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const muegiCell = document.createElement("td");
            muegiCell.classList.add(tdclass);
            muegiCell.classList.add(tdurlminwidth);
            muegiCell.innerHTML = getSubLevels(item.muegi.url) || "";
            row.appendChild(muegiCell);
        }

        if (item.objektloader === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const objloaderCell = document.createElement("td");
            objloaderCell.classList.add(tdclass);
            objloaderCell.classList.add(tdurlminwidth);
            objloaderCell.innerHTML = "Port: "+item.objektloader.port._text || "";
            row.appendChild(objloaderCell);
        }

        if (item.webconsole === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const webconsoleCell = document.createElement("td");
            webconsoleCell.classList.add(tdclass);
            webconsoleCell.innerHTML = "Port: "+item.webconsole.port._text || "";
            row.appendChild(webconsoleCell);
        }

        if (item.owinserver === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const owinCell = document.createElement("td");
            owinCell.classList.add(tdclass);
            owinCell.classList.add(tdurlminwidth);
            owinCell.innerHTML = "Mandant: "+item.owinserver.mand._text+"<br/>";
            owinCell.innerHTML += "Port private: "+item.owinserver.port.private._text+"<br/>";
            owinCell.innerHTML += "Port public: "+item.owinserver.port.public._text;
            row.appendChild(owinCell);
        }

        if (item.sts === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const stsCell = document.createElement("td");
            stsCell.classList.add(tdclass);
            stsCell.classList.add(tdurlminwidth);
            stsCell.innerHTML = "DesktopClient: "+item.sts.desktopclient._text+"<br/>";
            stsCell.innerHTML += "Entra App: "+item.sts.ea._text;
            row.appendChild(stsCell);
        }

        const jobsCell = document.createElement("td");
        jobsCell.classList.add(tdclass);
        jobsCell.classList.add(tdurlminwidth);
        if (item.jobs) {
            if (item.jobs.adrsync) {
                jobsCell.innerHTML += "<b>Adr. Sync: </b>"+item.jobs.adrsync._text+"<br/>" || "";
            }
            if (item.jobs.fulltextoptimize) {
                jobsCell.innerHTML += "<b>Fulltext Index Optimize: </b>"+item.jobs.fulltextoptimize._text+"<br/>" || "";
            }
            if (item.jobs.fulltextrebuild) {
                jobsCell.innerHTML += "<b>Fulltext Index Rebuild: </b>"+item.jobs.fulltextrebuild._text || "";
            }
        }
        row.appendChild(jobsCell);

        const dbhostCell = document.createElement("td");
        dbhostCell.classList.add(tdclass);
        dbhostCell.textContent = item.database.host._text || "";
        row.appendChild(dbhostCell);

        const dbnameCell = document.createElement("td");
        dbnameCell.classList.add(tdclass);
        dbnameCell.textContent = item.database.name._text || "";
        row.appendChild(dbnameCell);



        // Append row to the table body
        tableBody.appendChild(row);
    });
}

// Function to run a script with specified arguments
async function runScriptFullOverview(app, env, relay_handling) {
    // Prepare the output element
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

            // ----- Access the response data for debugging -----
            //const status = result.Status || "Unknown";
            //const data = result.Data || [];
            //tableRaw.textContent += `Status: ${status}\nData:\n${JSON.stringify(data, null, 2)}`;
            
            tableRaw.textContent = "";
            populateTable(result.Data || [], app, env, relay_handling);
        } else {
            const error = await response.json();
            tableRaw.textContent += `Error: ${error.error}`;
        }
    } catch (error) {
        tableRaw.textContent += `Error: ${error.message}`;
    }
}
