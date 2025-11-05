/**
 * MetaTool Editor - Class-based implementation
 * Manages MetaTool.ini file viewing and editing
 */
class MetaToolEditor {
    constructor() {
        this.currentFile = '';
        this.currentServer = '';
        this.preContent = document.getElementById('metatool-content');
        this.saveBtn = document.getElementById('saveBtn');
        this.init();
    }

    init() {
        this.attachTableListeners();
        this.attachSaveListener();
        this.loadInitialData();
    }

    loadInitialData() {
        runScriptMetatoolList('cmi', 'prod');
        runScriptMetatoolList('ais', 'prod');
        runScriptMetatoolList('cmi', 'test');
        runScriptMetatoolList('ais', 'test');
    }

    attachTableListeners() {
        // Use event delegation for all tables
        document.querySelectorAll('table').forEach(table => {
            table.addEventListener('click', (e) => this.handleFileClick(e));
        });
    }

    async handleFileClick(e) {
        if (e.target.tagName.toLowerCase() !== 'a') return;

        e.preventDefault();
        this.currentFile = e.target.dataset.file;
        this.currentServer = e.target.dataset.server;

        if (!this.currentFile || !this.currentServer) {
            showToast('Error', 'Missing file path or server information', 'danger');
            return;
        }

        this.preContent.textContent = 'Loading...';

        try {
            const url = `/get-file?file=${encodeURIComponent(this.currentFile)}&server=${encodeURIComponent(this.currentServer)}`;
            const response = await fetch(url);
            const data = await response.json();

            if (data.error) {
                this.preContent.textContent = `Error: ${data.error}`;
                showToast('Load Error', data.error, 'danger');
            } else {
                this.preContent.textContent = data.content;
                showToast('File Loaded', `${this.currentFile} loaded successfully`, 'success');
            }
        } catch (error) {
            this.preContent.textContent = `Fetch error: ${error}`;
            showToast('Network Error', error.message, 'danger');
        }
    }

    attachSaveListener() {
        this.saveBtn.addEventListener('click', () => this.saveFile());
    }

    async saveFile() {
        if (!this.currentFile || !this.currentServer) {
            showToast('Save Error', 'No file path or server selected', 'warning');
            return;
        }

        const buttonState = setButtonLoading(this.saveBtn, 'Saving...');

        try {
            const response = await fetch('/update-metatool', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    server: this.currentServer,
                    file: this.currentFile,
                    content: this.preContent.textContent
                })
            });

            const data = await response.json();

            if (data.error) {
                buttonState.setError('Failed');
                showToast('Save Failed', data.error, 'danger');
                setTimeout(() => buttonState.restore(), 3000);
            } else {
                buttonState.setSuccess('Saved');
                showToast('File Saved', `${this.currentFile} saved successfully`, 'success');
                setTimeout(() => buttonState.restore(), 3000);
            }
        } catch (error) {
            buttonState.setError('Error');
            showToast('Network Error', error.message, 'danger');
            setTimeout(() => buttonState.restore(), 3000);
        }
    }
}

// Function to populate the table with MetaTool data
function populateTable(data, app, env) {
    const tdclass = "py-1";

    let table;

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
        nameCell.textContent = item.namefull._text || "";
        nameCell.setAttribute('scope', 'row');
        row.appendChild(nameCell);

        const metatoolFilePathServerCell = document.createElement("td");
        metatoolFilePathServerCell.classList.add(tdclass);
        if (item.app.installpath._text) {
            const serverLink = document.createElement("a");
            serverLink.href = "#";
            const filePath = `${item.app.installpath._text}\\Server\\MetaTool.ini`;
            serverLink.textContent = "MetaTool.ini SERVER";
            serverLink.dataset.file = filePath;
            serverLink.dataset.server = item.app.host._text;
            metatoolFilePathServerCell.appendChild(serverLink);
        }
        row.appendChild(metatoolFilePathServerCell);

        const metatoolFilePathClientCell = document.createElement("td");
        metatoolFilePathClientCell.classList.add(tdclass);
        if (item.app.installpath._text) {
            const clientLink = document.createElement("a");
            clientLink.href = "#";
            const filePath = `${item.app.installpath._text}\\Client\\MetaTool.ini`;
            clientLink.textContent = "MetaTool.ini CLIENT";
            clientLink.dataset.file = filePath;
            clientLink.dataset.server = item.app.host._text;
            metatoolFilePathClientCell.appendChild(clientLink);
        }
        row.appendChild(metatoolFilePathClientCell);

        tableBody.appendChild(row);
    });
}

// Function to run a script with specified arguments
async function runScriptMetatoolList(app, env) {
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
            tableRaw.textContent = "";
            populateTable(result.Data || [], app, env);
        } else {
            const error = await response.json();
            tableRaw.textContent += `Error: ${error.error}`;
            showToast('Script Error', error.error, 'danger');
        }
    } catch (error) {
        tableRaw.textContent += `Error: ${error.message}`;
        showToast('Network Error', error.message, 'danger');
    }
}

// Initialize MetaTool Editor when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    new MetaToolEditor();
});
