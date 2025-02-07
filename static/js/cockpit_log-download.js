document.getElementById("get-log-files-btn").addEventListener("click", async function () {
    // Reset the result span
    const resultSpan = document.querySelector(".get-date-result");
    resultSpan.textContent = "";

    // Get the entered date and selected environment
    const logDate = document.getElementById("input-log-date").value.trim();
    const env = document.querySelector('input[name="log-env"]:checked').value;

    // Validate date input field
    const dateRegex = /^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$/; // yyyymmdd format

    if (!dateRegex.test(logDate)) {
        resultSpan.textContent = "Invalid date format. Please use yyyymmdd.";
        resultSpan.style.color = "red";
        return;
    }

    // Show "Downloading..." in the span
    resultSpan.style.color = "black"; // Reset the color to neutral
    resultSpan.textContent = "Downloading...";

    // Call the Flask endpoint
    try {
        const response = await fetch(`/get-log-files?log_date=${logDate}&env=${env}`, {
            method: "GET",
        });

        if (response.ok) {
            const blob = await response.blob();
            const downloadUrl = URL.createObjectURL(blob);

            // Create a temporary link to download the file
            const link = document.createElement("a");
            link.href = downloadUrl;

            // Extract filename from response headers or use a default name
            const contentDisposition = response.headers.get("Content-Disposition");
            let filename = "logs.zip"; // Default filename
            if (contentDisposition) {
                const match = contentDisposition.match(/filename=\"(.+)\"/);
                if (match) {
                    filename = match[1];
                }
            }

            link.download = filename;
            document.body.appendChild(link); // Append to DOM for Firefox compatibility
            link.click();
            document.body.removeChild(link); // Clean up

            URL.revokeObjectURL(downloadUrl); // Clean up the URL
            resultSpan.textContent = "Download complete.";
        } else {
            const error = await response.json();
            resultSpan.textContent = `Error: ${error.error}`;
            resultSpan.style.color = "red";
        }
    } catch (error) {
        resultSpan.textContent = `Error: ${error.message}`;
        resultSpan.style.color = "red";
    }
});