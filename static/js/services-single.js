document.addEventListener("DOMContentLoaded", function(event) {
    getServicesStatus();
});

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
                    </tr>
                  </thead>
                  <tbody></tbody>
                `;
                let tbody = table.querySelector("tbody");
                // Für jeden Eintrag: Zwei Zeilen erzeugen
                endpoint.entries.forEach(entry => {
                    // Zeile für den ersten Service
                    let tr1 = document.createElement("tr");
                    tr1.innerHTML = `
                        <td>${entry.hostname}</td>
                        <td>${entry.namefull}</td>
                        <td>${entry.servicename}</td>
                        <td>App</td>
                        <td><code class="${entry.status_service}">${entry.status_service}</code></td>
                    `;
                    tbody.appendChild(tr1);
                    // Zeile für den Relay-Service
                    let tr2 = document.createElement("tr");
                    tr2.innerHTML = `
                        <td>${entry.hostname}</td>
                        <td>${entry.namefull}</td>
                        <td>${entry.servicenamerelay}</td>
                        <td>Relay</td>
                        <td><code class="${entry.status_relay}">${entry.status_relay}</code></td>
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

