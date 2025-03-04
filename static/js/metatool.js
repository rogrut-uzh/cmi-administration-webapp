document.addEventListener("DOMContentLoaded", function(event) {
    runScriptMetatoolList('cmi', 'prod');
    runScriptMetatoolList('ais', 'prod');
    runScriptMetatoolList('cmi', 'test');
    runScriptMetatoolList('ais', 'test');
});

function getSubLevels(u) {
    if (u) { // only if u is not undefined (= there are urls)
        if (typeof u === "string") {
            return u;
        } else {
            var r = "";
                for (var i = 0; i < u.length; i++) {
                    r += "<br/>";
                    r += u[i];
                }
            return r;
        }
    }
}

function populateTable(data, app, env) {
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
    
    const tableBody = document.createElement("tbody");
    table.appendChild(tableBody);
    

    // Loop through JSON data and create rows
    data.forEach(item => {
        const row = document.createElement("tr");

        const nameCell = document.createElement("th");
        nameCell.classList.add(tdclass);
        nameCell.textContent = item.nameshort || "";
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        const metatoolFilePathServer = document.createElement("td");
        metatoolFilePathServer.classList.add(tdclass);
        metatoolFilePathServer.textContent = item.app.installpath ? `${item.app.installpath}/Server/MetaTool.ini` : "";
        row.appendChild(metatoolFilePathServer);

        const metatoolFilePathClient = document.createElement("td");
        metatoolFilePathClient.classList.add(tdclass);
        metatoolFilePathClient.textContent = item.app.installpath ? `${item.app.installpath}/Client/MetaTool.ini` : "";
        row.appendChild(metatoolFilePathClient);

        // Append row to the table body
        tableBody.appendChild(row);
    });
}

// Function to run a script with specified arguments
async function runScriptMetatoolList(app, env) {
    // Prepare the output element
    const tableRaw = document.getElementById("tableRaw");
    tableRaw.textContent = `Running script with: App=${app}, Env=${env}...\n`;

    try {
        const response = await fetch('/run-script-metatool', {
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
