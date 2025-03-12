document.addEventListener("DOMContentLoaded", function() {
    fetch('/services-single')
        .then(response => response.json())
        .then(data => {
            // data ist ein Array mit den Endpunkt-Daten
            data.forEach(endpoint => {
                // Beispiel: Füge für jeden Endpunkt ein HTML-Element hinzu
                let container = document.getElementById("services-container");
                let card = document.createElement("div");
                card.className = "card mb-3";
                
                let header = document.createElement("div");
                header.className = "card-header";
                header.innerHTML = `<h3>${endpoint.label}</h3>`;
                card.appendChild(header);
                
                let body = document.createElement("div");
                body.className = "card-body";
                
                // Erstelle eine Tabelle
                let table = document.createElement("table");
                table.className = "table table-striped table-bordered";
                table.innerHTML = `
                  <thead>
                    <tr>
                      <th>Hostname</th>
                      <th>Status (Service)</th>
                      <th>Status (Relay Service)</th>
                    </tr>
                  </thead>
                  <tbody></tbody>
                `;
                let tbody = table.querySelector("tbody");
                // Fülle die Zeilen aus den Einträgen
                endpoint.entries.forEach(entry => {
                    let tr = document.createElement("tr");
                    tr.innerHTML = `
                        <td>${entry.hostname}</td>
                        <td>${entry.status_service}</td>
                        <td>${entry.status_relay}</td>
                    `;
                    tbody.appendChild(tr);
                });
                body.appendChild(table);
                card.appendChild(body);
                container.appendChild(card);
            });
        })
        .catch(error => {
            console.error("Error fetching services:", error);
        });
});
