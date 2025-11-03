/**
 * Table Sorting - Pure Vanilla JavaScript (No jQuery)
 * Sortiert Tabellen beim Klick auf Header-Zellen
 */

document.addEventListener('DOMContentLoaded', function() {
    // Event Delegation für alle sortierbaren Tabellen-Header
    document.addEventListener('click', function(e) {
        const th = e.target.closest('table thead tr th:not(.no-sort)');
        if (!th) return;

        const table = th.closest('table');
        const tbody = table.querySelector('tbody');
        const rows = Array.from(tbody.querySelectorAll('tr'));
        const columnIndex = Array.from(th.parentNode.children).indexOf(th);
        
        // Sortierrichtung bestimmen
        const currentDir = th.classList.contains('sort-asc') ? 'desc' : 'asc';
        
        // Zeilen sortieren
        rows.sort(tableComparer(columnIndex));
        
        if (currentDir === 'desc') {
            rows.reverse();
        }
        
        // Sortierte Zeilen wieder ins tbody einfügen
        rows.forEach(row => tbody.appendChild(row));
        
        // Sortier-Klassen aktualisieren
        table.querySelectorAll('thead tr th').forEach(header => {
            header.classList.remove('sort-asc', 'sort-desc');
        });
        th.classList.add('sort-' + currentDir);
    });
});

/**
 * Prüft ob ein String ein gültiges Datum ist
 */
function isDate(val) {
    const d = new Date(val);
    return !isNaN(d.valueOf());
}

/**
 * Gibt den Text-Inhalt einer Tabellenzelle zurück
 */
function tableCellValue(row, index) {
    const cell = row.children[index];
    return cell ? cell.textContent.trim() : '';
}

/**
 * Vergleichsfunktion für Array.sort()
 */
function tableComparer(index) {
    return function(a, b) {
        let valA = tableCellValue(a, index).replace(/[$,]/g, '');
        let valB = tableCellValue(b, index).replace(/[$,]/g, '');
        
        // Numerischer Vergleich
        if (!isNaN(valA) && !isNaN(valB)) {
            return parseFloat(valA) - parseFloat(valB);
        }
        
        // Datums-Vergleich
        if (isDate(valA) && isDate(valB)) {
            return new Date(valA) - new Date(valB);
        }
        
        // String-Vergleich (lokalisiert)
        return valA.toString().localeCompare(valB, undefined, { numeric: true, sensitivity: 'base' });
    };
}