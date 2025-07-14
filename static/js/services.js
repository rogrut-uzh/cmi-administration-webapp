// Function to run a script with specified arguments
function runScriptServices(action, app, env, groupId) {
    // Disable only the buttons in this group
    disableButtonGroup(groupId);

    // Prepare the output element
    const outputElement = document.getElementById("output");
    outputElement.textContent = `Running script with: Action=${action}, App=${app}, Env=${env}...\n`;

    // Create an EventSource for real-time updates
    const eventSource = new EventSource(`/run-script-services-stream?action=${action}&app=${app}&env=${env}`);

    // Handle incoming data from the server
    eventSource.onmessage = (event) => {
        outputElement.textContent += `${event.data}\n`;
    };

    // Handle errors
    eventSource.onerror = () => {
        outputElement.textContent += "\nConnection closed.";
        eventSource.close();
        enableButtonGroup(groupId); // Re-enable the buttons in this group
    };
}

// Disable only buttons within a specific group
function disableButtonGroup(groupId) {
    const buttons = document.querySelectorAll(`#${groupId} button`);
    buttons.forEach(button => button.disabled = true);
}

// Enable only buttons within a specific group
function enableButtonGroup(groupId) {
    const buttons = document.querySelectorAll(`#${groupId} button`);
    buttons.forEach(button => button.disabled = false);
}
