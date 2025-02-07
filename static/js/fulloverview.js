document.addEventListener("DOMContentLoaded", function(event) {
    runScriptFullOverview('cmi', 'prod');
    runScriptFullOverview('ais', 'prod');
    runScriptFullOverview('cmi', 'test');
    runScriptFullOverview('ais', 'test');
});

function getSubLevels(u) {
    var r = "";
    if (u) { // only if u is not undefined (= there are urls)
        for (var i = 0; i < u.length; i++) {
            r += "<br/>";
            r += u[i];
        }
    }
    return r;
}

function populateTable(data, app, env) {
    const tdclass = "py-1";
    
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
    
    const nameshortCellHeader = document.createElement("th");
    nameshortCellHeader.classList.add(tdclass);
    nameshortCellHeader.textContent = "Short Name";
    tableHeadTr.appendChild(nameshortCellHeader);
    
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
    
    const servicenameCellHeader = document.createElement("th");
    servicenameCellHeader.classList.add(tdclass);
    servicenameCellHeader.textContent = "Service Name";
    tableHeadTr.appendChild(servicenameCellHeader);
    
    const serviceuserCellHeader = document.createElement("th");
    serviceuserCellHeader.classList.add(tdclass);
    serviceuserCellHeader.textContent = "Service User";
    tableHeadTr.appendChild(serviceuserCellHeader);
    
    const servicenamerelayCellHeader = document.createElement("th");
    servicenamerelayCellHeader.classList.add(tdclass);
    servicenamerelayCellHeader.textContent = "Service Name Relay";
    tableHeadTr.appendChild(servicenamerelayCellHeader);
    
    const serviceuserrelayCellHeader = document.createElement("th");
    serviceuserrelayCellHeader.classList.add(tdclass);
    serviceuserrelayCellHeader.textContent = "Service User Relay";
    tableHeadTr.appendChild(serviceuserrelayCellHeader);
    
    const dbhostCellHeader = document.createElement("th");
    dbhostCellHeader.classList.add(tdclass);
    dbhostCellHeader.textContent = "DB Host";
    tableHeadTr.appendChild(dbhostCellHeader);
    
    const dbnameCellHeader = document.createElement("th");
    dbnameCellHeader.classList.add(tdclass);
    dbnameCellHeader.textContent = "DB Name";
    tableHeadTr.appendChild(dbnameCellHeader);
    
    const licenseCellHeader = document.createElement("th");
    licenseCellHeader.classList.add(tdclass);
    licenseCellHeader.textContent = "License Server";
    tableHeadTr.appendChild(licenseCellHeader);
    
    const licenseportCellHeader = document.createElement("th");
    licenseportCellHeader.classList.add(tdclass);
    licenseportCellHeader.textContent = "License Server Port";
    tableHeadTr.appendChild(licenseportCellHeader);
    
    const mobileCellHeader = document.createElement("th");
    mobileCellHeader.classList.add(tdclass);
    mobileCellHeader.textContent = "Mobile Client";
    tableHeadTr.appendChild(mobileCellHeader);
    
    const mobileAppsCellHeader = document.createElement("th");
    mobileAppsCellHeader.classList.add(tdclass);
    mobileAppsCellHeader.textContent = "Mobile Apps";
    tableHeadTr.appendChild(mobileAppsCellHeader);
    
    const ueberweisungCellHeader = document.createElement("th");
    ueberweisungCellHeader.classList.add(tdclass);
    ueberweisungCellHeader.textContent = "Ueberweisungen";
    tableHeadTr.appendChild(ueberweisungCellHeader);
    
    const objloaderCellHeader = document.createElement("th");
    objloaderCellHeader.classList.add(tdclass);
    objloaderCellHeader.textContent = "Objekt Loader";
    tableHeadTr.appendChild(objloaderCellHeader);
    
    const webconsoleCellHeader = document.createElement("th");
    webconsoleCellHeader.classList.add(tdclass);
    webconsoleCellHeader.textContent = "Webconsole";
    tableHeadTr.appendChild(webconsoleCellHeader);
    
    const jobsCellHeader = document.createElement("th");
    jobsCellHeader.classList.add(tdclass);
    jobsCellHeader.textContent = "Jobs";
    tableHeadTr.appendChild(jobsCellHeader);

    // Loop through JSON data and create rows
    data.forEach(item => {
        const row = document.createElement("tr");

        const nameCell = document.createElement("th");
        nameCell.classList.add(tdclass);
        nameCell.textContent = item.namefull || "";
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        const nameshortCell = document.createElement("th");
        nameshortCell.classList.add(tdclass);
        nameshortCell.textContent = item.nameshort || "";
        nameshortCell.setAttribute('scope', 'row');
        row.appendChild(nameshortCell);

        const versionCell = document.createElement("td");
        versionCell.classList.add(tdclass);
        versionCell.textContent = item.app.releaseversion || "";
        row.appendChild(versionCell);

        const hostCell = document.createElement("td");
        hostCell.classList.add(tdclass);
        hostCell.textContent = item.app.host || "";
        row.appendChild(hostCell);

        const installpathCell = document.createElement("td");
        installpathCell.classList.add(tdclass);
        installpathCell.textContent = item.app.installpath || "";
        row.appendChild(installpathCell);

        const servicenameCell = document.createElement("td");
        servicenameCell.classList.add(tdclass);
        servicenameCell.textContent = item.app.servicename || "";
        row.appendChild(servicenameCell);

        const serviceuserCell = document.createElement("td");
        serviceuserCell.classList.add(tdclass);
        serviceuserCell.textContent = item.app.serviceuser || "";
        row.appendChild(serviceuserCell);

        const servicenamerelayCell = document.createElement("td");
        servicenamerelayCell.classList.add(tdclass);
        servicenamerelayCell.textContent = item.app.servicenamerelay || "";
        row.appendChild(servicenamerelayCell);

        const serviceuserrelayCell = document.createElement("td");
        serviceuserrelayCell.classList.add(tdclass);
        serviceuserrelayCell.textContent = item.app.serviceuserrelay || "";
        row.appendChild(serviceuserrelayCell);

        const dbhostCell = document.createElement("td");
        dbhostCell.classList.add(tdclass);
        dbhostCell.textContent = item.database.host || "";
        row.appendChild(dbhostCell);

        const dbnameCell = document.createElement("td");
        dbnameCell.classList.add(tdclass);
        dbnameCell.textContent = item.database.name || "";
        row.appendChild(dbnameCell);

        if (item.licenseserver === undefined) {
            row.appendChild(document.createElement("td"));
			row.appendChild(document.createElement("td"));
        } else {
            const licenseCell = document.createElement("td");
            licenseCell.classList.add(tdclass);
            licenseCell.textContent = item.licenseserver.server || "";
            row.appendChild(licenseCell);

            const licenseportCell = document.createElement("td");
            licenseportCell.classList.add(tdclass);
            licenseportCell.textContent = item.licenseserver.port || "";
            row.appendChild(licenseportCell);
        }

        if (item.mobilefirst === undefined) {
            row.appendChild(document.createElement("td"));
		} else {
			const mobilefirstCell = document.createElement("td");
			mobilefirstCell.classList.add(tdclass);
			let link = document.createElement("a");
			link.href = item.mobilefirst;
			link.textContent = item.mobilefirst;
			link.target = "_blank";
			mobilefirstCell.appendChild(link);
			row.appendChild(mobilefirstCell);
		}

        if (item.mobile === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
            const mobileCell = document.createElement("td");
            mobileCell.classList.add(tdclass);
            if (item.mobile.sitzungsvorbereitung !== undefined) {
			    let link = document.createElement("a");
			    link.href = item.mobile.sitzungsvorbereitung;
			    link.textContent = item.mobile.sitzungsvorbereitung;
			    link.target = "_blank";
                mobileCell.appendChild(link);
                mobileCell.appendChild(document.createElement("br")); 
            }
            if (item.mobile.zusammenarbeitdritte !== undefined) {
			    let link = document.createElement("a");
			    link.href = item.mobile.zusammenarbeitdritte;
			    link.textContent = item.mobile.zusammenarbeitdritte;
			    link.target = "_blank";
                mobileCell.appendChild(link);
                mobileCell.appendChild(document.createElement("br")); 
            }
            if (item.mobile.dossierbrowser !== undefined) {
			    let link = document.createElement("a");
			    link.href = item.mobile.dossierbrowser;
			    link.textContent = item.mobile.dossierbrowser;
			    link.target = "_blank";
                mobileCell.appendChild(link);
                mobileCell.appendChild(document.createElement("br")); 
            }
			row.appendChild(mobileCell);
        }

        if (item.ueberweisung === undefined) {
            row.appendChild(document.createElement("td"));
		} else {
            const ueberweisungCell = document.createElement("td");
            ueberweisungCell.classList.add(tdclass);
            ueberweisungCell.innerHTML = "Port: "+item.ueberweisung.port || "";
            ueberweisungCell.innerHTML += getSubLevels(item.ueberweisung.url) || "";
            row.appendChild(ueberweisungCell);
        }

        if (item.objektloader === undefined) {
            row.appendChild(document.createElement("td"));
		} else {
            const objloaderCell = document.createElement("td");
            objloaderCell.classList.add(tdclass);
            objloaderCell.innerHTML = "Port: "+item.objektloader.port || "";
            row.appendChild(objloaderCell);
        }

        if (item.webconsole === undefined) {
            row.appendChild(document.createElement("td"));
		} else {
            const webconsoleCell = document.createElement("td");
            webconsoleCell.classList.add(tdclass);
            webconsoleCell.innerHTML = "Port: "+item.webconsole.port || "";
            row.appendChild(webconsoleCell);
        }
        
        const jobsCell = document.createElement("td");
        jobsCell.classList.add(tdclass);
        if (item.jobs) {
            if (item.jobs.adrsync) {
                jobsCell.innerHTML += "<b>Adr. Sync: </b>"+item.jobs.adrsync+"<br/>" || "";
            }
            if (item.jobs.fulltextoptimize) {
                jobsCell.innerHTML += "<b>Fulltext Index Optimize: </b>"+item.jobs.fulltextoptimize+"<br/>" || "";
            }
            if (item.jobs.fulltextrebuild) {
                jobsCell.innerHTML += "<b>Fulltext Index Rebuild: </b>"+item.jobs.fulltextrebuild || "";
            }
        }
        row.appendChild(jobsCell);

        // Append row to the table body
        tableBody.appendChild(row);
    });
}

// Function to run a script with specified arguments
async function runScriptFullOverview(app, env) {
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
            populateTable(result.Data || [], app, env);
        } else {
            const error = await response.json();
            tableRaw.textContent += `Error: ${error.error}`;
        }
    } catch (error) {
        tableRaw.textContent += `Error: ${error.message}`;
    }
}
