function getDatabases(job, env) {
    const table_title = env;
    env = env.toLowerCase()
    // Zeige den Spinner, falls er nicht sichtbar ist
    document.getElementById("loading").style.display = "block";

    // Verarbeite data vom pwsh script
    fetch('/run-script-db-stream?job='+job+'&env='+env)
        .then(response => {
            if (!response.ok) {
                throw new Error("HTTP error " + response.status);
            }
            return response.json();
        })
        .then(data => {
            // Verstecke den Spinner, sobald die Daten geladen sind
            document.getElementById("loading").style.display = "none";
            
            // Tabelle erstellen
            let table = document.createElement("table");
            table.className = "table table-striped table-bordered sortable";
            table.innerHTML = `
                <thead>
                  <tr>
                    <th>Mandant</th>
                    <th>DB Host</th>
                    <th>DB Name</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody></tbody>`;

            // Container für die Karten
            let container = document.getElementById("databases-container");
            let card = document.createElement("div");
            card.className = "card mb-3";

            let body = document.createElement("div");
            body.className = "card-body";

            let h2 = document.createElement("h2");
            h2.textContent = table_title;
            h2.className = "card-title";
            body.appendChild(h2);

            let tbody = table.querySelector("tbody");
            data.forEach(item => {
                const namefull = removeAllWhitespace(item.namefull);
                const dbhost = removeAllWhitespace(item.dbhost);
                const dbname = removeAllWhitespace(item.dbname);
                let tr = document.createElement("tr");
                tr.innerHTML = `
                    <td>${namefull}</td>
                    <td>${dbhost}</td>
                    <td>${dbname}</td>
                    <td><button class="btn btn-sm btn-primary" onclick="triggerDbBackup('${dbname}', '${dbhost}', this)">Backup</button></td>`;
                tbody.appendChild(tr);
            });
            body.appendChild(table);
            card.appendChild(body);
            container.appendChild(card);
        })
        .catch(error => {
            console.error("Error fetching services:", error);
            document.getElementById("loading").style.display = "none";
        });
}

function triggerDbBackup(db, dbhost, buttonElement) {
    const buttonState = setButtonLoading(buttonElement, 'Running...');

    // Timeout after 5 minutes (300000ms) for long-running backups
    const timeoutId = setTimeout(() => {
        buttonState.restore();
        showToast('Backup Timeout', `Backup for ${db} timed out. Please check status manually.`, 'warning');
    }, 300000);

    fetch(`/database-backup?db=${db}&dbhost=${dbhost}`)
        .then(response => {
            clearTimeout(timeoutId);
            return response.json();
        })
        .then(data => {
            if (data.error) {
                // Error: restore button and show error toast
                buttonState.setError('Failed');
                showToast('Backup Failed', data.error, 'danger');

                // Restore button after 3 seconds
                setTimeout(() => buttonState.restore(), 3000);
            } else {
                // Success: show success state
                buttonState.setSuccess('Completed');
                showToast('Backup Successful', `Database ${db} on ${dbhost} backed up successfully.`, 'success');

                // Restore button after 10 seconds
                setTimeout(() => buttonState.restore(), 10000);
            }
        })
        .catch(error => {
            clearTimeout(timeoutId);
            buttonState.setError('Error');
            showToast('Network Error', error.message || 'Failed to connect to server', 'danger');

            // Restore button after 3 seconds
            setTimeout(() => buttonState.restore(), 3000);
        });
}


// removeAllWhitespace is now in utils.js

document.addEventListener("DOMContentLoaded", function(event) {
    getDatabases("list", "Test");
    getDatabases("list", "Prod");
});

