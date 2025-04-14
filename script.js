document.addEventListener('DOMContentLoaded', () => {
    const fileInput = document.getElementById('xmlFile');
    const fileInfo = document.getElementById('fileInfo');
    const outputArea = document.getElementById('outputArea');
    const outputCodeElement = document.getElementById('outputCode');
    const copyButton = document.getElementById('copyButton');
    const statusElement = document.getElementById('status');

    fileInput.addEventListener('change', handleFileSelect);
    copyButton.addEventListener('click', copyToClipboard);

    function handleFileSelect(event) {
        const file = event.target.files[0];
        clearStatus();
        outputArea.style.display = 'none';

        if (!file) {
            fileInfo.textContent = 'No file selected.';
            return;
        }

        const allowedExtensions = /(\.xml|\.fnt|\.txt)$/i;
        if (!allowedExtensions.exec(file.name)) {
            showStatus(`Error: Invalid file type. Please select .xml, .fnt, or .txt`, 'error');
            fileInput.value = '';
             fileInfo.textContent = 'No file selected.';
            return;
        }

        fileInfo.textContent = `Selected file: ${file.name} (${formatBytes(file.size)})`;

        const reader = new FileReader();

        reader.onload = function(e) {
            try {
                const xmlContent = e.target.result;
                const luaCode = convertXmlToLua(xmlContent);

                if (luaCode.startsWith('Error:')) {
                    showStatus(luaCode, 'error');
                    outputArea.style.display = 'none';
                } else {
                    outputCodeElement.textContent = luaCode;
                    outputArea.style.display = 'block';
                    showStatus('Conversion successful!', 'success');
                    resetCopyButton();
                }
            } catch (error) {
                console.error("Conversion error:", error);
                showStatus(`Error during conversion: ${error.message}. Check console for details.`, 'error');
                outputArea.style.display = 'none';
            }
        };

        reader.onerror = function(e) {
            console.error("File reading error:", e);
            showStatus(`Error reading file: ${e.target.error}`, 'error');
             fileInfo.textContent = `Error reading ${file.name}`;
             outputArea.style.display = 'none';
        };

        reader.readAsText(file);
    }

    function convertXmlToLua(xml) {
        xml = xml.replace(/\s+/g, ' ').trim();

        const extractInteger = (elementString, attribute) => {
            const match = elementString.match(new RegExp(`${attribute}\\s*=\\s*"(-?\\d+)"`));
            return match ? parseInt(match[1], 10) : null;
        };

        let fontSize = null;
        const infoMatch = xml.match(/<info([^>]+)>/);
        if (infoMatch && infoMatch[1]) {
            fontSize = extractInteger(infoMatch[1], 'size');
             if (fontSize === null || isNaN(fontSize)) {
                 if (!infoMatch[1].match(/face=|charset=|padding=|spacing=/)) {
                     return "Error: Could not find a valid <info> element. Is the file format BMFont XML?";
                 }
                 return "Error: Missing or invalid 'size' attribute in <info> element.";
            }
        } else {
            return "Error: Missing <info> element. Make sure the file is in BMFont XML format.";
        }

        const characters = [];
        const charRegex = /<char([^>]+)\/>/g;
        let match;

        while ((match = charRegex.exec(xml)) !== null) {
            const attributes = match[1];

            const id = extractInteger(attributes, 'id');
            if (id !== null && !isNaN(id)) {
                const width = extractInteger(attributes, 'width');
                const height = extractInteger(attributes, 'height');
                const x = extractInteger(attributes, 'x');
                const y = extractInteger(attributes, 'y');
                const xOffset = extractInteger(attributes, 'xoffset');
                const yOffset = extractInteger(attributes, 'yoffset');
                const xAdvance = extractInteger(attributes, 'xadvance');

                if ([width, height, x, y, xOffset, yOffset, xAdvance].some(val => val === null || isNaN(val))) {
                    return `Error: Character data (id=${id}) is missing or invalid. Ensure attributes (width, height, x, y, xoffset, yoffset, xadvance) are present and are integers.`;
                }

                const char = String.fromCharCode(id);
                const escapedChar = char.replace(/\\/g, '\\\\').replace(/"/g, '\\"');

                characters.push(
                    `\t\t["${escapedChar}"] = {${width}, ${height}, Vector2.new(${x}, ${y}), ${xOffset}, ${yOffset}, ${xAdvance}}`
                );
            } else {
                 console.warn("Found <char> tag with missing or invalid 'id' attribute:", match[0]);
            }
        }

         if (characters.length === 0 && xml.includes('<chars') && xml.includes('count=')) {
             const charsCountMatch = xml.match(/<chars\s+count="(\d+)"/);
             if (charsCountMatch && parseInt(charsCountMatch[1], 10) > 0) {
                return "Error: Found <chars count> indicating characters exist, but couldn't parse any <char .../> elements. Check XML structure.";
             } else if (!charsCountMatch) {
                 return "Error: Expected <chars count='...'> element, but it was not found or invalid.";
             }
         } else if (characters.length === 0 && !xml.includes('<chars')) {
             console.warn("No <char../> elements found and no <chars count='...'> tag detected.");
         }


        let output = `{\n\tSize = ${fontSize},\n\tCharacters = {\n`;
        output += characters.join(',\n');
        output += `\n\t}\n}`;

        return output;
    }

    function copyToClipboard() {
        if (!outputCodeElement.textContent) return;

        navigator.clipboard.writeText(outputCodeElement.textContent)
            .then(() => {
                const buttonText = copyButton.querySelector('span');
                const originalText = buttonText.textContent;
                buttonText.textContent = 'Copied!';
                copyButton.disabled = true;
                setTimeout(() => {
                   buttonText.textContent = originalText;
                    copyButton.disabled = false;
                }, 1500);
            })
            .catch(err => {
                console.error('Failed to copy text: ', err);
                showStatus('Error: Could not copy text to clipboard.', 'error');
            });
    }

    function resetCopyButton() {
        const buttonText = copyButton.querySelector('span');
        buttonText.textContent = 'Copy';
        copyButton.disabled = false;
    }

    function showStatus(message, type = 'info') {
        statusElement.textContent = message;
        statusElement.className = `status ${type}`;
        statusElement.style.display = 'block';
    }

     function clearStatus() {
        statusElement.textContent = '';
        statusElement.style.display = 'none';
        statusElement.className = 'status';
    }

    function formatBytes(bytes, decimals = 2) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }

});
