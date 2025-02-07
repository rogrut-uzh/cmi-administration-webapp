document.addEventListener("DOMContentLoaded", function(event) {
    runScriptCockpitOverview('cmi', 'prod');
    runScriptCockpitOverview('ais', 'prod');
    runScriptCockpitOverview('cmi', 'test');
    runScriptCockpitOverview('ais', 'test');
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
    
    const versionCellHeader = document.createElement("th");
    versionCellHeader.classList.add(tdclass);
    versionCellHeader.textContent = "Release";
    tableHeadTr.appendChild(versionCellHeader);
    
    const hostCellHeader = document.createElement("th");
    hostCellHeader.classList.add(tdclass);
    hostCellHeader.textContent = "Host";
    tableHeadTr.appendChild(hostCellHeader);
    
    const licenseCellHeader = document.createElement("th");
    licenseCellHeader.classList.add(tdclass);
    licenseCellHeader.textContent = "License Server";
    tableHeadTr.appendChild(licenseCellHeader);
    
    const mobileCellHeader = document.createElement("th");
    mobileCellHeader.classList.add(tdclass);
    mobileCellHeader.textContent = "Mobile Client";
    tableHeadTr.appendChild(mobileCellHeader);
    
    const jobsCellHeader = document.createElement("th");
    jobsCellHeader.classList.add(tdclass);
    jobsCellHeader.textContent = "Jobs";
    tableHeadTr.appendChild(jobsCellHeader);
    

    // Loop through JSON data and create rows
    data.forEach(item => {
        const row = document.createElement("tr");

        // Create cells for each column
        //const environmentCell = document.createElement("td");
        //environmentCell.classList.add(tdclass);
        //environmentCell.textContent = env || "";
        //row.appendChild(environmentCell);
        //
        //const appTypeCell = document.createElement("td");
        //appTypeCell.classList.add(tdclass);
        //appTypeCell.textContent = app || "";
        //row.appendChild(appTypeCell);

        const nameCell = document.createElement("th");
        nameCell.classList.add(tdclass);
        nameCell.textContent = item.namefull || "";
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        const versionCell = document.createElement("td");
        versionCell.classList.add(tdclass);
        versionCell.textContent = item.app.releaseversion || "";
        row.appendChild(versionCell);

        const hostCell = document.createElement("td");
        hostCell.classList.add(tdclass);
        hostCell.textContent = item.app.host || "";
        row.appendChild(hostCell);

        const licenseCell = document.createElement("td");
        licenseCell.classList.add(tdclass);
        licenseCell.textContent = item.licenseserver ? "Yes" : "No";
        row.appendChild(licenseCell);

        const mobileCell = document.createElement("td");
        mobileCell.classList.add(tdclass);
        const link = document.createElement("a");
        link.href = item.mobilefirst;
        link.textContent = item.mobilefirst;
        link.target = "_blank";
        mobileCell.appendChild(link);
        row.appendChild(mobileCell);
        
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
async function runScriptCockpitOverview(app, env) {
    // Prepare the output element
    const tableRaw = document.getElementById("tableRaw");
    tableRaw.textContent = `Running script with: App=${app}, Env=${env}...\n`;

    try {
        const response = await fetch('/run-script-cockpit-overview', {
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
