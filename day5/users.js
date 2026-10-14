const API_URL = "https://jsonplaceholder.typicode.com/users";

const loadBtn = document.querySelector("#load-users");
const filterInput = document.querySelector("#filter-input");
const statusText = document.querySelector("#status");
const listEl = document.querySelector("#users-list");

let allUsers = [];

// Render an array of users securely using createElement and textContent
function renderUsers(users) {
  listEl.innerHTML = "";

  if (users.length === 0) {
    statusText.textContent = "No users match your filter.";
    return;
  }

  users.forEach(user => {
    const li = document.createElement("li");

    const nameEl = document.createElement("strong");
    nameEl.textContent = user.name;
    nameEl.style.fontSize = "1.1rem";

    const detailsEl = document.createElement("div");
    detailsEl.style.marginTop = "4px";
    detailsEl.textContent = `Email: ${user.email} | City: ${user.address.city} | Company: ${user.company.name}`;

    li.appendChild(nameEl);
    li.appendChild(detailsEl);
    listEl.appendChild(li);
  });
}

// Fetch users with loading, success, and error states
async function loadUsers() {
  statusText.textContent = "Loading users...";
  loadBtn.disabled = true;
  listEl.innerHTML = "";
  filterInput.value = "";

  try {
    const response = await fetch(API_URL);
    if (!response.ok) {
      throw new Error(`Failed to fetch (Status: ${response.status})`);
    }

    allUsers = await response.json();
    renderUsers(allUsers);
    statusText.textContent = `Successfully loaded ${allUsers.length} users.`;
  } catch (error) {
    statusText.textContent = "Could not load users. Please try again.";
    console.error(error);
  } finally {
    loadBtn.disabled = false;
  }
}

// Event Listeners
loadBtn.addEventListener("click", loadUsers);

filterInput.addEventListener("input", (e) => {
  const query = e.target.value.toLowerCase().trim();
  const filtered = allUsers.filter(user => 
    user.name.toLowerCase().includes(query)
  );
  
  renderUsers(filtered);
  
  if (filtered.length > 0 && allUsers.length > 0) {
    statusText.textContent = `Showing ${filtered.length} of ${allUsers.length} users.`;
  }
});