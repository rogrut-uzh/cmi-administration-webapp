document.getElementById("get-config-files-btn").addEventListener("click", async function () {
    // Reset the result span
    const resultSpan = document.querySelector(".get-date-result-config");
    resultSpan.textContent = "";

    // Get the entered date and selected environment
    const env = document.querySelector('input[name="log-env"]:checked').value;

    // Show "Downloading..." in the span
    resultSpan.style.color = "black"; // Reset the color to neutral
    resultSpan.textContent = "Downloading...";

    // Call the Flask endpoint
    try {
        const response = await fetch(`/get-config-files`, {
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
            let filename = "cmi-config-files.zip"; // Default filename
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