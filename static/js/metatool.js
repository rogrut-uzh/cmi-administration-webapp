document.addEventListener("DOMContentLoaded", function(event) {
    runScriptMetatoolList('cmi', 'prod');
    runScriptMetatoolList('ais', 'prod');
    runScriptMetatoolList('cmi', 'test');
    runScriptMetatoolList('ais', 'test');
});

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
if (item.nameshort === "Informatik" && item.app.host === "ziaxiomatap02") {
        const row = document.createElement("tr");

        const nameCell = document.createElement("th");
        nameCell.classList.add(tdclass);
        nameCell.textContent = item.nameshort || "";
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        // Beispiel für den "Server" Link
        const metatoolFilePathServerCell = document.createElement("td");
        metatoolFilePathServerCell.classList.add(tdclass);
        if (item.app.installpath) {
          // Erstelle ein Anchor-Element statt nur Text
          const serverLink = document.createElement("a");
          serverLink.href = "#";
          // Doppelte Backslashes, da der Backslash ein Escape-Zeichen ist
          const filePath = `${item.app.installpath}\\Server\\MetaTool.ini`;
          serverLink.textContent = filePath;
          // Speichere Dateipfad und Servername als Data-Attribute
          serverLink.dataset.file = filePath;
          serverLink.dataset.server = item.app.host; // Servername kommt hier aus item.app.host
          metatoolFilePathServerCell.appendChild(serverLink);
        }
        row.appendChild(metatoolFilePathServerCell);

        // Beispiel für den "Client" Link
        const metatoolFilePathClientCell = document.createElement("td");
        metatoolFilePathClientCell.classList.add(tdclass);
        if (item.app.installpath) {
          const clientLink = document.createElement("a");
          clientLink.href = "#";
          const filePath = `${item.app.installpath}\\Client\\MetaTool.ini`;
          clientLink.textContent = filePath;
          clientLink.dataset.file = filePath;
          clientLink.dataset.server = item.app.host;
          metatoolFilePathClientCell.appendChild(clientLink);
        }
        row.appendChild(metatoolFilePathClientCell);

        // Append row to the table body
        tableBody.appendChild(row);
}
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


document.addEventListener('DOMContentLoaded', function() {
  const preContent = document.getElementById('metatool-content');
  let currentFile = '';
  let currentServer = '';

  // Event Delegation: Fange Klicks auf alle <a>-Elemente in deiner Tabelle ab
  document.querySelector('table').addEventListener('click', function(e) {
    if (e.target.tagName.toLowerCase() === 'a') {
      e.preventDefault();
      currentFile = e.target.dataset.file;
      currentServer = e.target.dataset.server;
      // Lade den Inhalt der Datei vom Remote-Server über den Flask-Endpunkt, der per PowerShell updatet/liest
      fetch(`/get-file?file=${encodeURIComponent(currentFile)}&server=${encodeURIComponent(currentServer)}`)
        .then(response => response.json())
        .then(data => {
          if (data.error) {
            preContent.textContent = `Error: ${data.error}`;
          } else {
            preContent.textContent = data.content;
          }
        })
        .catch(error => preContent.textContent = `Fetch error: ${error}`);
    }
  });

  // SAVE-Button: sende den bearbeiteten Inhalt und die aktuellen Daten an den Remote-Update-Endpunkt
  document.getElementById('saveBtn').addEventListener('click', function() {
    if (!currentFile || !currentServer) {
      alert("Kein Dateipfad oder Server ausgewählt!");
      return;
    }
    const newContent = preContent.textContent;
    fetch('/update-metatool', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        server: currentServer,
        file: currentFile,
        content: newContent
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        alert("Fehler beim Speichern: " + data.error);
      } else {
        alert("Datei erfolgreich gespeichert!");
      }
    })
    .catch(error => alert("Fetch error: " + error));
  });
});
