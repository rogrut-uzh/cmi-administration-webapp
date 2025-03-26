function getServicesStatus() {
	
    // Zeige den Spinner, falls er nicht sichtbar ist
    document.getElementById("loading").style.display = "block";
	
    fetch('/run-script-services-single-stream?env='+env)
        .then(response => response.json())
        .then(data => {
            // data ist ein Array mit den Endpunkt-Daten
            data.forEach(endpoint => {
				
				// Verstecke den Spinner, sobald die Daten geladen sind
				document.getElementById("loading").style.display = "none";
				
                // Container für die Karten
                let container = document.getElementById("services-container");
                let card = document.createElement("div");
                card.className = "card mb-3";
                
                let body = document.createElement("div");
                body.className = "card-body";
                
                let h2 = document.createElement("h2");
                h2.innerHTML = `${endpoint.label}`;
                h2.className = "card-title";
                body.appendChild(h2);
                
                // Tabelle erstellen
                let table = document.createElement("table");
                table.className = "table table-striped table-bordered sortable";
                table.innerHTML = `
                  <thead>
                    <tr>
                      <th>Hostname</th>
                      <th>Mandant</th>
                      <th>Service Name</th>
                      <th>Anwendung</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody></tbody>
                `;
                let tbody = table.querySelector("tbody");
                // Für jeden Eintrag: Zwei Zeilen erzeugen
                endpoint.entries.forEach(entry => {
                    // Table Zeile für den ersten Service
                    let tr1 = document.createElement("tr");
                    const idSafeServiceName = removeAllWhitespace(entry.servicename);
					let button_start_disabled1 = " disabled";
					let button_stop_disabled1 = " disabled";
					if (entry.status_service === "running") { 
					    button_stop_disabled1 = ""; 
					}
					if (entry.status_service === "stopped") { 
					    button_start_disabled1 = ""; 
					}
                    tr1.innerHTML = `
                        <td>${entry.hostname}</td>
                        <td>${entry.namefull}</td>
                        <td>${entry.servicename}</td>
                        <td>App</td>
                        <td>
                            <code id="status-${idSafeServiceName}" class="${entry.status_service}">${entry.status_service}</code>
                        </td>
                        <td>
                            <button class="btn btn-primary btn-sm" id="btn_start_${entry.servicename}" data-hostname="${entry.hostname}" data-service="${entry.servicename}" data-action="start"${button_start_disabled1}>Start</button>
                            <button class="btn btn-primary btn-sm" id="btn_stop_${entry.servicename}" data-hostname="${entry.hostname}" data-service="${entry.servicename}" data-action="stop"${button_stop_disabled1}>Stop</button>
                        </td>
                    `;
                    tbody.appendChild(tr1);
                    // Table Zeile für den Relay-Service
                    let tr2 = document.createElement("tr");
                    const idSafeServiceNameRelay = removeAllWhitespace(entry.servicenamerelay);
					let button_start_disabled2 = " disabled";
					let button_stop_disabled2 = " disabled";
					if (entry.status_relay === "running") { 
					    button_stop_disabled2 = ""; 
					}
					if (entry.status_relay === "stopped") { 
					    button_start_disabled2 = ""; 
					}
                    tr2.innerHTML = `
                        <td>${entry.hostname}</td>
                        <td>${entry.namefull}</td>
                        <td>${entry.servicenamerelay}</td>
                        <td>Relay</td>
                        <td>
                            <code id="status-${idSafeServiceNameRelay}" class="${entry.status_relay}">${entry.status_relay}</code>
                        </td>
                        <td>
                            <button class="btn btn-primary btn-sm" id="btn_start_${entry.servicenamerelay}" data-hostname="${entry.hostname}" data-service="${entry.servicenamerelay}" data-action="start"${button_start_disabled2}>Start</button>
                            <button class="btn btn-primary btn-sm" id="btn_stop_${entry.servicenamerelay}" data-hostname="${entry.hostname}" data-service="${entry.servicenamerelay}" data-action="stop"${button_stop_disabled2}>Stop</button>
                        </td>
                    `;
                    tbody.appendChild(tr2);
                });
                body.appendChild(table);
                card.appendChild(body);
                container.appendChild(card);
            });
        })
        .catch(error => {
            console.error("Error fetching services:", error);
			document.getElementById("loading").style.display = "none";
        });
}

function controlService(hostname, service, action) {
    
    //alert(`Clicked ${action} on ${service} at ${hostname}`);
    
    fetch('/service-control', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            service: service,
            action: action,
            hostname: hostname
        })
    })
    .then(res => res.json())
    .then(data => {
        if (data.status) {
            // Neuen Status anzeigen
            serviceClean = removeAllWhitespace(service);
            const statusCell = document.getElementById(`status-${serviceClean}`);
            if (statusCell) {
                statusCell.textContent = data.status;
                statusCell.classList.remove('running', 'stopped', 'unknown');
                statusCell.classList.add(data.status);
            }
			
            // Passende Buttons aktivieren/deaktivieren
            const parentTd = document.querySelector(`button[data-service="${service}"][data-hostname="${hostname}"]`)?.parentElement;
            if (parentTd) {
                const startBtn = parentTd.querySelector(`button[data-action="start"]`);
                const stopBtn = parentTd.querySelector(`button[data-action="stop"]`);

                if (data.status === 'running') {
                    startBtn.disabled = true;
                    stopBtn.disabled = false;
                } else if (data.status === 'stopped') {
                    startBtn.disabled = false;
                    stopBtn.disabled = true;
                } else {
                    // z. B. "unknown" → beide deaktivieren oder ausblenden
                    startBtn.disabled = true;
                    stopBtn.disabled = true;
                }
            }
        } else {
            alert("Fehler: " + (data.error || "Unbekannter Fehler"));
        }
    })
    .catch(err => {
        console.error(err);
        alert("Netzwerkfehler oder Server nicht erreichbar");
    });
}

function removeAllWhitespace(str) {
    return str.replace(/\s+/g, '');
}

document.addEventListener("DOMContentLoaded", function(event) {
    getServicesStatus();
});

document.getElementById("services-container").addEventListener("click", function(e) {
    if (e.target.tagName === "BUTTON" && e.target.dataset.action) {
        const action = e.target.dataset.action;
        const hostname = e.target.dataset.hostname;
        const service = e.target.dataset.service;
        
        controlService(hostname, service, action);
    }
});
