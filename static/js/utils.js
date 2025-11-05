/**
 * Utility Functions for CMI Administration WebApp
 * Common helper functions used across multiple JavaScript files
 */

/**
 * Shows a Bootstrap toast notification
 * @param {string} title - Toast title
 * @param {string} message - Toast message
 * @param {string} type - Bootstrap color type (success, danger, warning, info)
 */
function showToast(title, message, type = 'info') {
    const toastContainer = document.getElementById('toast-container');
    if (!toastContainer) {
        console.error('Toast container not found');
        // Fallback to alert if toast container doesn't exist
        alert(`${title}\n${message}`);
        return;
    }

    const toast = document.createElement('div');
    toast.className = `toast align-items-center text-bg-${type} border-0`;
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'assertive');
    toast.setAttribute('aria-atomic', 'true');
    toast.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">
                <strong>${escapeHtml(title)}</strong><br>${escapeHtml(message)}
            </div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
    `;

    toastContainer.appendChild(toast);
    const bsToast = new bootstrap.Toast(toast, {
        autohide: true,
        delay: 5000
    });
    bsToast.show();

    // Remove toast from DOM after it's hidden
    toast.addEventListener('hidden.bs.toast', () => toast.remove());
}

/**
 * Escapes HTML special characters to prevent XSS attacks
 * @param {string} unsafe - String that may contain HTML
 * @returns {string} Escaped string safe for innerHTML
 */
function escapeHtml(unsafe) {
    if (!unsafe) return "";
    return String(unsafe)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

/**
 * Removes all whitespace from a string
 * @param {string} str - Input string
 * @returns {string} String without whitespace
 */
function removeAllWhitespace(str) {
    return str ? str.replace(/\s+/g, '') : '';
}

/**
 * Makes an API POST request with consistent error handling
 * @param {string} url - API endpoint URL
 * @param {object} data - Data to send in request body
 * @param {number} timeout - Request timeout in milliseconds (default: 120000)
 * @returns {Promise<object>} Response data
 */
async function apiPost(url, data, timeout = 120000) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
            signal: controller.signal
        });

        clearTimeout(timeoutId);

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.error || `HTTP ${response.status}`);
        }

        return await response.json();
    } catch (error) {
        clearTimeout(timeoutId);

        if (error.name === 'AbortError') {
            throw new Error('Request timeout - please try again');
        }

        throw error;
    }
}

/**
 * Makes an API GET request with consistent error handling
 * @param {string} url - API endpoint URL
 * @param {number} timeout - Request timeout in milliseconds (default: 120000)
 * @returns {Promise<object>} Response data
 */
async function apiGet(url, timeout = 120000) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
        const response = await fetch(url, {
            method: 'GET',
            signal: controller.signal
        });

        clearTimeout(timeoutId);

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.error || `HTTP ${response.status}`);
        }

        return await response.json();
    } catch (error) {
        clearTimeout(timeoutId);

        if (error.name === 'AbortError') {
            throw new Error('Request timeout - please try again');
        }

        throw error;
    }
}

/**
 * Sets button to loading state with spinner
 * @param {HTMLButtonElement} button - Button element
 * @param {string} loadingText - Text to show during loading (default: "Loading...")
 * @returns {object} Object with restore() method to restore original state
 */
function setButtonLoading(button, loadingText = 'Loading...') {
    const originalText = button.innerHTML;
    const originalDisabled = button.disabled;
    const originalClass = button.className;

    button.disabled = true;
    button.innerHTML = `<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>${escapeHtml(loadingText)}`;

    return {
        restore: () => {
            button.innerHTML = originalText;
            button.disabled = originalDisabled;
            button.className = originalClass;
        },
        setSuccess: (text = 'Success') => {
            button.innerHTML = `<i class="bi bi-check-circle"></i> ${escapeHtml(text)}`;
            button.classList.remove('btn-primary', 'btn-warning', 'btn-danger');
            button.classList.add('btn-success');
        },
        setError: (text = 'Error') => {
            button.innerHTML = `<i class="bi bi-x-circle"></i> ${escapeHtml(text)}`;
            button.classList.remove('btn-primary', 'btn-warning', 'btn-success');
            button.classList.add('btn-danger');
        }
    };
}

/**
 * Clones a table and replaces <br> tags with separators for Excel export
 * @param {HTMLTableElement} table - Table to clone
 * @param {string} separator - Separator to use instead of <br> (default: " | ")
 * @returns {HTMLTableElement} Cloned table
 */
function cloneTableWithLinebreaks(table, separator = ' | ') {
    const clone = table.cloneNode(true);
    clone.querySelectorAll('td, th').forEach(cell => {
        cell.innerHTML = cell.innerHTML.replace(/<br\s*\/?>/gi, separator);
    });
    return clone;
}

/**
 * Downloads a table as XLSX file
 * @param {string} tableId - ID of the table element
 * @param {string} filename - Filename for the download
 */
function downloadTableAsXlsx(tableId, filename) {
    const table = document.getElementById(tableId);
    if (!table) {
        showToast('Error', 'Table not found', 'danger');
        return;
    }

    try {
        const clone = cloneTableWithLinebreaks(table);
        const wb = XLSX.utils.table_to_book(clone, {sheet: "Tabelle"});
        XLSX.writeFile(wb, filename);
        showToast('Download', `File ${filename} downloaded successfully`, 'success');
    } catch (error) {
        showToast('Download Error', error.message, 'danger');
    }
}
