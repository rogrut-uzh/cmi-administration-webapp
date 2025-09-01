document.addEventListener("DOMContentLoaded", function(event) {
    runScriptCockpitOverview();
});


function populateTable(data) {
    console.log(data);
    const tdclass = "py-1";
    
    var table = document.querySelector("#dataTableCmi");
    
    const tableHead = document.createElement("thead");
    table.appendChild(tableHead);
    
    const tableBody = document.createElement("tbody");
    table.appendChild(tableBody);
    
    
    const tableHeadTr = document.createElement("tr");
    tableHead.appendChild(tableHeadTr);
    
    
    
    const namefullCellHeader = document.createElement("th");
    namefullCellHeader.classList.add(tdclass);
    namefullCellHeader.textContent = "Name";
    tableHeadTr.appendChild(namefullCellHeader);
    
    const releaseversionCellHeader = document.createElement("th");
    releaseversionCellHeader.classList.add(tdclass);
    releaseversionCellHeader.textContent = "Release";
    tableHeadTr.appendChild(releaseversionCellHeader);
    
    const envCellHeader = document.createElement("th");
    envCellHeader.classList.add(tdclass);
    envCellHeader.textContent = "Env";
    tableHeadTr.appendChild(envCellHeader);
    
    const apptypeCellHeader = document.createElement("th");
    apptypeCellHeader.classList.add(tdclass);
    apptypeCellHeader.textContent = "Typ";
    tableHeadTr.appendChild(apptypeCellHeader);
    
    const mandCellHeader = document.createElement("th");
    mandCellHeader.classList.add(tdclass);
    mandCellHeader.textContent = "Mandant";
    tableHeadTr.appendChild(mandCellHeader);
    
    const hostCellHeader = document.createElement("th");
    hostCellHeader.classList.add(tdclass);
    hostCellHeader.textContent = "Host";
    tableHeadTr.appendChild(hostCellHeader);
    
    const webCellHeader = document.createElement("th");
    webCellHeader.classList.add(tdclass);
    webCellHeader.textContent = "Web";
    tableHeadTr.appendChild(webCellHeader);
    
    const licenseCellHeader = document.createElement("th");
    licenseCellHeader.classList.add(tdclass);
    licenseCellHeader.textContent = "Lic.Server";
    tableHeadTr.appendChild(licenseCellHeader);
    

//  Name/namefull | Release/releaseversion | Env/env | Typ/apptype | Mandant/mand | Host/host | Web/web | Lic.Server/license


    // Loop through JSON data and create rows
    data.forEach(item => {
        const row = document.createElement("tr");

        const namefullCell = document.createElement("td");
        namefullCell.classList.add(tdclass);
        namefullCell.textContent = item.namefull._text || "";
        //nameCell.innerHTML = "<b>"+item.namefull._text+"</b>" || "";
        namefullCell.setAttribute('scope', 'row');
        row.appendChild(namefullCell);

        const releaseversionCell = document.createElement("td");
        releaseversionCell.classList.add(tdclass);
        releaseversionCell.textContent = item.app.releaseversion._text || "";
        row.appendChild(releaseversionCell);

        const envCell = document.createElement("td");
        envCell.classList.add(tdclass);
        envCell.textContent = item.environment || "";
        row.appendChild(envCell);

        const apptypeCell = document.createElement("td");
        apptypeCell.classList.add(tdclass);
        apptypeCell.textContent = item.apptype || "";
        row.appendChild(apptypeCell);

        const mandCell = document.createElement("td");
        mandCell.classList.add(tdclass);
        mandCell.textContent = item?.mand?._text ?? item?.mand ?? "";
        row.appendChild(mandCell);

        const hostCell = document.createElement("td");
        hostCell.classList.add(tdclass);
        hostCell.textContent = item.app.host._text || "";
        row.appendChild(hostCell);

        if (item.mobilefirst === undefined) {
            row.appendChild(document.createElement("td"));
        } else {
			const webCell = document.createElement("td");
			webCell.classList.add(tdclass);
			const link = document.createElement("a");
			link.href = item.mobilefirst._text;
			link.textContent = item.mobilefirst._text;
			link.target = "_blank";
			webCell.appendChild(link);
			row.appendChild(webCell);
		}
        
        const licenseCell = document.createElement("td");
        licenseCell.classList.add(tdclass);
        licenseCell.textContent = item.licenseserver ? "Yes" : "No";
        row.appendChild(licenseCell);

        // Append row to the table body
        tableBody.appendChild(row);
    });
}

// Function to run a script with specified arguments
async function runScriptCockpitOverview() {
    // Prepare the output element
    const tableRaw = document.getElementById("tableRaw");
    tableRaw.textContent = `Running script...\n`;

    try {
        const response = await fetch('/run-script-cockpit-overview', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: '{}'
        });
        if (response.ok) {
            const result = await response.json();

            // ----- Access the response data for debugging -----
            //const status = result.Status || "Unknown";
            //const data = result.Data || [];
            //tableRaw.textContent += `Status: ${status}\nData:\n${JSON.stringify(data, null, 2)}`;
            
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
