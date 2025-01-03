// URL of the API endpoint
const apiUrl = 'https://5wi0e9n5w0.execute-api.us-east-1.amazonaws.com/main/counter';

// Function to make the API call
async function fetchData() {
    try {
        const response = await fetch(apiUrl); // Make the API call
        if (!response.ok) { // Check if the response status is OK (200-299)
            throw new Error('Network response was not ok');
        }
        const data = await response.json(); // Parse the JSON data from the response
        document.getElementById('data').textContent = JSON.stringify(data, null, 2); // Display the data in the div
    } catch (error) {
        console.error('There was a problem with the fetch operation:', error);
        document.getElementById('data').textContent = 'Error fetching data!';
    }
}

// Call the function
fetchData();
