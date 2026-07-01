const STORAGE_KEY = "habithero-webapp-v2";
const LEGACY_STORAGE_KEY = "habithero-live-v1";

const dayOrder = [1, 2, 3, 4, 5, 6, 0];
const dayLabels = {
  0: "So",
  1: "Mo",
  2: "Di",
  3: "Mi",
  4: "Do",
  5: "Fr",
  6: "Sa",
};

const categoryDefinitions = {
  Gesundheit: { icon: "🌿", label: "Gesundheit" },
  Fitness: { icon: "💪", label: "Fitness" },
  Lernen: { icon: "📚", label: "Lernen" },
  Achtsamkeit: { icon: "🧘", label: "Achtsamkeit" },
  Produktivität: { icon: "⚡", label: "Produktivität" },
  Haushalt: { icon: "🏡", label: "Haushalt" },
  Kreativität: { icon: "🎨", label: "Kreativität" },
};

const badgeDefinitions = [
  {
    id: "first-habit",
    icon: "🌱",
    title: "Erster Schritt",
    description: "Mindestens ein Habit wurde erstellt.",
    unlocked: (state) => state.habits.length >= 1,
  },
  {
    id: "first-check",
    icon: "✅",
    title: "Erster Sieg",
    description: "Der erste Habit wurde erfolgreich abgehakt.",
    unlocked: (state) => totalCompletions(state.habits) >= 1,
  },
  {
    id: "three-habits",
    icon: "🎯",
    title: "Zielsammler",
    description: "Drei aktive Habits wurden erfasst.",
    unlocked: (state) => state.habits.length >= 3,
  },
  {
    id: "five-checks",
    icon: "⭐",
    title: "Dranbleiber",
    description: "Fünf Abschlüsse wurden erreicht.",
    unlocked: (state) => totalCompletions(state.habits) >= 5,
  },
  {
    id: "ten-checks",
    icon: "🏅",
    title: "Routine-Profi",
    description: "Zehn Abschlüsse wurden erreicht.",
    unlocked: (state) => totalCompletions(state.habits) >= 10,
  },
  {
    id: "three-streak",
    icon: "🔥",
    title: "3-Tage-Serie",
    description: "An drei Tagen in Folge wurde mindestens ein Habit erledigt.",
    unlocked: (state) => globalStreak(state.habits) >= 3 || maxGlobalStreak(state.habits) >= 3,
  },
  {
    id: "seven-streak",
    icon: "🚀",
    title: "7-Tage-Serie",
    description: "An sieben Tagen in Folge wurde mindestens ein Habit erledigt.",
    unlocked: (state) => globalStreak(state.habits) >= 7 || maxGlobalStreak(state.habits) >= 7,
  },
  {
    id: "perfect-day",
    icon: "👑",
    title: "Perfekter Tag",
    description: "Alle heute fälligen Habits wurden abgeschlossen.",
    unlocked: (state) => {
      const due = dueToday(state.habits);
      return due.length > 0 && due.every(isCompletedToday);
    },
  },
  {
    id: "level-three",
    icon: "🦸",
    title: "HabitHero",
    description: "Level 3 wurde erreicht.",
    unlocked: (state) => levelFromXp(totalXp(state.habits)) >= 3,
  },
];

let state = loadState();
let activeRoute = window.location.hash?.replace("#", "") || "dashboard";
let activeFilter = "all";
let searchTerm = "";
let toastTimer;

const elements = {
  heroProgressRing: document.querySelector("#heroProgressRing"),
  heroProgressValue: document.querySelector("#heroProgressValue"),
  heroProgressText: document.querySelector("#heroProgressText"),
  heroMotivation: document.querySelector("#heroMotivation"),
  currentStreak: document.querySelector("#currentStreak"),
  xpValue: document.querySelector("#xpValue"),
  levelValue: document.querySelector("#levelValue"),
  badgeCount: document.querySelector("#badgeCount"),
  levelPill: document.querySelector("#levelPill"),
  levelProgressFill: document.querySelector("#levelProgressFill"),
  levelProgressText: document.querySelector("#levelProgressText"),
  focusTitle: document.querySelector("#focusTitle"),
  focusText: document.querySelector("#focusText"),
  focusActionBtn: document.querySelector("#focusActionBtn"),
  habitSearch: document.querySelector("#habitSearch"),
  habitList: document.querySelector("#habitList"),
  completionRate: document.querySelector("#completionRate"),
  completionRateText: document.querySelector("#completionRateText"),
  bestStreak: document.querySelector("#bestStreak"),
  totalChecks: document.querySelector("#totalChecks"),
  weekChart: document.querySelector("#weekChart"),
  heatmap: document.querySelector("#heatmap"),
  habitPerformance: document.querySelector("#habitPerformance"),
  badgeGrid: document.querySelector("#badgeGrid"),
  habitModal: document.querySelector("#habitModal"),
  habitForm: document.querySelector("#habitForm"),
  habitFormTitle: document.querySelector("#habitFormTitle"),
  habitId: document.querySelector("#habitId"),
  habitTitle: document.querySelector("#habitTitle"),
  habitDescription: document.querySelector("#habitDescription"),
  habitCategory: document.querySelector("#habitCategory"),
  habitXp: document.querySelector("#habitXp"),
  weekdayOptions: document.querySelector("#weekdayOptions"),
  deleteHabitBtn: document.querySelector("#deleteHabitBtn"),
  importDataInput: document.querySelector("#importDataInput"),
  toast: document.querySelector("#toast"),
};

document.addEventListener("DOMContentLoaded", () => {
  renderCategoryOptions();
  renderWeekdayOptions();
  bindEvents();
  setRoute(isValidRoute(activeRoute) ? activeRoute : "dashboard", false);
  render();
});

function bindEvents() {
  document.querySelectorAll("[data-route]").forEach((element) => {
    element.addEventListener("click", (event) => {
      event.preventDefault();
      setRoute(event.currentTarget.dataset.route);
    });
  });

  document.querySelectorAll(".filter").forEach((button) => {
    button.addEventListener("click", (event) => {
      activeFilter = event.currentTarget.dataset.filter;
      updateFilterButtons();
      renderDashboard();
    });
  });

  elements.habitSearch.addEventListener("input", (event) => {
    searchTerm = event.target.value.trim().toLowerCase();
    renderDashboard();
  });

  ["#openCreateHabit", "#heroCreateHabit", "#statsCreateHabit"].forEach((selector) => {
    document.querySelector(selector).addEventListener("click", () => openHabitModal());
  });

  elements.focusActionBtn.addEventListener("click", () => {
    const firstOpen = firstOpenHabitToday();
    if (firstOpen) toggleToday(firstOpen.id);
    else openHabitModal();
  });

  document.querySelector("#loadDemoBtn").addEventListener("click", seedDemoData);
  document.querySelector("#heroDemoBtn").addEventListener("click", seedDemoData);
  document.querySelector("#exportDataBtn").addEventListener("click", exportData);
  document.querySelector("#resetDataBtn").addEventListener("click", resetData);
  elements.importDataInput.addEventListener("change", importData);

  document.querySelector("#closeHabitModal").addEventListener("click", closeHabitModal);
  document.querySelector("#cancelHabitForm").addEventListener("click", closeHabitModal);

  elements.habitModal.addEventListener("click", (event) => {
    if (event.target === elements.habitModal) closeHabitModal();
  });

  elements.habitForm.addEventListener("submit", saveHabitFromForm);
  elements.deleteHabitBtn.addEventListener("click", () => {
    const habitId = elements.habitId.value;
    if (!habitId) return;
    deleteHabit(habitId);
    closeHabitModal();
  });

  elements.habitList.addEventListener("click", handleHabitListClick);

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !elements.habitModal.hidden) closeHabitModal();
  });

  window.addEventListener("hashchange", () => {
    const route = window.location.hash.replace("#", "");
    if (isValidRoute(route)) setRoute(route, false);
  });
}

function loadState() {
  const fallback = { habits: [], createdAt: new Date().toISOString(), version: 2 };
  try {
    const stored = localStorage.getItem(STORAGE_KEY) || localStorage.getItem(LEGACY_STORAGE_KEY);
    if (!stored) return fallback;
    const parsed = JSON.parse(stored);
    if (!Array.isArray(parsed.habits)) return fallback;
    return normaliseState(parsed);
  } catch (error) {
    console.warn("HabitHero konnte gespeicherte Daten nicht lesen.", error);
    return fallback;
  }
}

function normaliseState(input) {
  return {
    createdAt: input.createdAt || new Date().toISOString(),
    version: 2,
    habits: input.habits.map((habit) => ({
      id: habit.id || createId(),
      title: String(habit.title || "Unbenannter Habit"),
      description: String(habit.description || ""),
      category: categoryDefinitions[habit.category] ? habit.category : "Gesundheit",
      xp: clamp(Number(habit.xp || 10), 5, 50),
      daysOfWeek: Array.isArray(habit.daysOfWeek) && habit.daysOfWeek.length > 0 ? habit.daysOfWeek.map(Number) : dayOrder,
      completedDates: Array.isArray(habit.completedDates) ? Array.from(new Set(habit.completedDates)).sort() : [],
      createdAt: habit.createdAt || new Date().toISOString(),
      updatedAt: habit.updatedAt || new Date().toISOString(),
    })),
  };
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function render() {
  renderSummary();
  renderDashboard();
  renderStats();
  renderBadges();
  updateRouteButtons();
  updateFilterButtons();
}

function renderSummary() {
  const todayHabits = dueToday(state.habits);
  const doneToday = todayHabits.filter(isCompletedToday).length;
  const progress = todayHabits.length === 0 ? 0 : Math.round((doneToday / todayHabits.length) * 100);
  const xp = totalXp(state.habits);
  const level = levelFromXp(xp);
  const nextLevelXp = level * 100;
  const previousLevelXp = (level - 1) * 100;
  const levelProgress = Math.min(100, Math.round(((xp - previousLevelXp) / 100) * 100));
  const unlockedBadges = badgeDefinitions.filter((badge) => badge.unlocked(state));
  const streak = globalStreak(state.habits);

  elements.heroProgressValue.textContent = `${progress}%`;
  elements.heroProgressRing.style.background = `conic-gradient(var(--green) ${progress * 3.6}deg, rgba(255,255,255,0.18) 0deg)`;
  elements.heroProgressText.textContent = `${doneToday} von ${todayHabits.length} Habits`;
  elements.heroMotivation.textContent = motivationText(progress, todayHabits.length);
  elements.currentStreak.textContent = `${streak} ${streak === 1 ? "Tag" : "Tage"}`;
  elements.xpValue.textContent = `${xp} XP`;
  elements.levelValue.textContent = `Level ${level}`;
  elements.badgeCount.textContent = `${unlockedBadges.length} / ${badgeDefinitions.length}`;
  elements.levelPill.textContent = `Level ${level}`;
  elements.levelProgressFill.style.width = `${levelProgress}%`;
  elements.levelProgressText.textContent = `Noch ${Math.max(0, nextLevelXp - xp)} XP bis Level ${level + 1}.`;

  const firstOpen = firstOpenHabitToday();
  if (todayHabits.length === 0) {
    elements.focusTitle.textContent = "Heute ist frei";
    elements.focusText.textContent = "Für heute ist kein Habit geplant. Erfasse einen neuen Habit oder nutze die Zeit bewusst zur Erholung.";
    elements.focusActionBtn.textContent = "Habit erfassen";
  } else if (firstOpen) {
    elements.focusTitle.textContent = firstOpen.title;
    elements.focusText.textContent = firstOpen.description || "Ein kleiner Schritt reicht, um die heutige Serie fortzusetzen.";
    elements.focusActionBtn.textContent = "Jetzt abhaken";
  } else {
    elements.focusTitle.textContent = "Perfekter Tag";
    elements.focusText.textContent = "Alle heutigen Habits sind erledigt. Genau so entsteht Fortschritt.";
    elements.focusActionBtn.textContent = "Weiteren Habit erfassen";
  }
}

function renderDashboard() {
  const today = getTodayKey();
  let habits = state.habits.map((habit) => ({
    ...habit,
    due: habit.daysOfWeek.includes(new Date().getDay()),
    done: habit.completedDates.includes(today),
  }));

  if (activeFilter === "open") habits = habits.filter((habit) => habit.due && !habit.done);
  if (activeFilter === "done") habits = habits.filter((habit) => habit.done);
  if (searchTerm) {
    habits = habits.filter((habit) => {
      const haystack = `${habit.title} ${habit.description} ${habit.category}`.toLowerCase();
      return haystack.includes(searchTerm);
    });
  }

  if (habits.length === 0) {
    elements.habitList.innerHTML = `
      <div class="empty-state">
        <div>
          <div class="emoji">🦸</div>
          <h3>Noch keine passenden Habits</h3>
          <p>Erfasse einen ersten Habit oder lade Demo-Daten. Danach kannst du HabitHero direkt im Browser testen und präsentieren.</p>
          <button class="button button-primary" type="button" data-action="create-empty">Habit erfassen</button>
        </div>
      </div>
    `;
    return;
  }

  elements.habitList.innerHTML = habits
    .map((habit) => {
      const category = categoryDefinitions[habit.category] || categoryDefinitions.Gesundheit;
      const streak = currentHabitStreak(habit);
      const successRate = habitSuccessRate(habit, 30);
      const statusLabel = habit.due ? (habit.done ? "Heute erledigt" : "Heute offen") : "Heute nicht fällig";
      const statusClass = habit.due ? "status-pill" : "status-pill muted";
      return `
        <article class="habit-card ${habit.done ? "is-done" : ""} ${!habit.due ? "is-muted" : ""}" data-id="${habit.id}">
          <button class="check-button ${habit.done ? "is-done" : ""}" type="button" data-action="toggle" ${habit.due ? "" : "disabled"} aria-label="${escapeHtml(habit.title)} abhaken">
            ${habit.done ? "✓" : ""}
          </button>
          <div class="habit-content">
            <div class="habit-meta">
              <span class="category-pill">${category.icon} ${escapeHtml(category.label)}</span>
              <span class="${statusClass}">${statusLabel}</span>
              · ${streak} ${streak === 1 ? "Tag" : "Tage"} Serie · ${successRate}% in 30 Tagen
            </div>
            <h3>${escapeHtml(habit.title)}</h3>
            ${habit.description ? `<p class="habit-description">${escapeHtml(habit.description)}</p>` : ""}
            <div class="habit-days">${formatDays(habit.daysOfWeek).map((day) => `<span class="day-pill">${day}</span>`).join("")}</div>
          </div>
          <div class="habit-actions">
            <button class="small-button" type="button" data-action="edit">Bearbeiten</button>
            <button class="small-button danger" type="button" data-action="delete">Löschen</button>
          </div>
        </article>
      `;
    })
    .join("");
}

function renderStats() {
  const rate = globalCompletionRate(30);
  elements.completionRate.textContent = `${rate.percent}%`;
  elements.completionRateText.textContent = `${rate.done} von ${rate.due} fälligen Habit-Tagen erledigt.`;
  const best = Math.max(0, ...state.habits.map(currentHabitStreak), maxGlobalStreak(state.habits));
  elements.bestStreak.textContent = `${best} ${best === 1 ? "Tag" : "Tage"}`;
  elements.totalChecks.textContent = totalCompletions(state.habits);
  renderWeekChart();
  renderHeatmap();
  renderHabitPerformance();
}

function renderWeekChart() {
  const days = getCurrentWeekDays();
  elements.weekChart.innerHTML = days
    .map((day) => {
      const due = dueHabitsOnDate(day.key).length;
      const done = completionsOnDate(day.key);
      const percent = due === 0 ? 0 : Math.round((done / due) * 100);
      const height = due === 0 ? 6 : Math.max(12, Math.round(percent * 1.55));
      return `
        <div class="chart-day" title="${day.longLabel}: ${done}/${due} erledigt">
          <div class="chart-stack" aria-hidden="true">
            <div class="chart-bar" style="height: ${height}px"></div>
          </div>
          <span>${day.label}</span>
          <strong>${done}/${due}</strong>
        </div>
      `;
    })
    .join("");
}

function renderHeatmap() {
  const days = getLastNDays(14).map((key) => {
    const due = dueHabitsOnDate(key).length;
    const done = completionsOnDate(key);
    const percent = due === 0 ? 0 : Math.round((done / due) * 100);
    return { key, due, done, percent, date: parseDateKey(key) };
  });

  elements.heatmap.innerHTML = days
    .map((day) => {
      const level = heatLevel(day.percent, day.due);
      return `
        <div class="heat-cell" data-level="${level}" title="${formatDateShort(day.date)}: ${day.done}/${day.due} erledigt">
          <strong>${dayLabels[day.date.getDay()]}</strong>
          <span>${formatDateShort(day.date)}</span><br>
          <span>${day.done}/${day.due} · ${day.percent}%</span>
        </div>
      `;
    })
    .join("");
}

function renderHabitPerformance() {
  if (state.habits.length === 0) {
    elements.habitPerformance.innerHTML = `<p class="habit-description">Noch keine Habits vorhanden. Lade Demo-Daten oder erfasse einen ersten Habit.</p>`;
    return;
  }

  const sorted = [...state.habits].sort((a, b) => habitSuccessRate(b, 30) - habitSuccessRate(a, 30));
  elements.habitPerformance.innerHTML = sorted
    .map((habit) => {
      const rate = habitCompletionStats(habit, 30);
      const streak = currentHabitStreak(habit);
      return `
        <div class="performance-item">
          <div class="performance-header">
            <strong>${escapeHtml(habit.title)}</strong>
            <span>${rate.percent}% · ${rate.done}/${rate.due} fällig · ${streak} ${streak === 1 ? "Tag" : "Tage"} Serie</span>
          </div>
          <div class="progress-track"><div class="progress-fill" style="width: ${rate.percent}%"></div></div>
        </div>
      `;
    })
    .join("");
}

function renderBadges() {
  elements.badgeGrid.innerHTML = badgeDefinitions
    .map((badge) => {
      const unlocked = badge.unlocked(state);
      return `
        <article class="panel badge-card ${unlocked ? "is-unlocked" : ""}">
          <div class="badge-icon">${badge.icon}</div>
          <h3>${badge.title}</h3>
          <p>${badge.description}</p>
          <span class="badge-status">${unlocked ? "Freigeschaltet" : "Noch offen"}</span>
        </article>
      `;
    })
    .join("");
}

function renderCategoryOptions() {
  elements.habitCategory.innerHTML = Object.keys(categoryDefinitions)
    .map((key) => `<option value="${key}">${categoryDefinitions[key].icon} ${categoryDefinitions[key].label}</option>`)
    .join("");
}

function renderWeekdayOptions(selectedDays = dayOrder) {
  elements.weekdayOptions.innerHTML = dayOrder
    .map(
      (day) => `
        <label>
          <input type="checkbox" name="days" value="${day}" ${selectedDays.includes(day) ? "checked" : ""} />
          <span>${dayLabels[day]}</span>
        </label>
      `
    )
    .join("");
}

function handleHabitListClick(event) {
  const action = event.target.dataset.action;
  if (action === "create-empty") {
    openHabitModal();
    return;
  }
  if (!action) return;

  const card = event.target.closest(".habit-card");
  if (!card) return;

  const habitId = card.dataset.id;
  if (action === "toggle") toggleToday(habitId);
  if (action === "edit") openHabitModal(habitId);
  if (action === "delete") deleteHabit(habitId);
}

function openHabitModal(habitId = null) {
  const habit = state.habits.find((item) => item.id === habitId);
  elements.habitForm.reset();
  elements.habitId.value = habit ? habit.id : "";
  elements.habitFormTitle.textContent = habit ? "Habit bearbeiten" : "Neuen Habit erfassen";
  elements.habitTitle.value = habit ? habit.title : "";
  elements.habitDescription.value = habit ? habit.description : "";
  elements.habitCategory.value = habit ? habit.category : "Gesundheit";
  elements.habitXp.value = habit ? habit.xp : 10;
  elements.deleteHabitBtn.hidden = !habit;
  renderWeekdayOptions(habit ? habit.daysOfWeek : dayOrder);
  elements.habitModal.hidden = false;
  window.setTimeout(() => elements.habitTitle.focus(), 0);
}

function closeHabitModal() {
  elements.habitModal.hidden = true;
}

function saveHabitFromForm(event) {
  event.preventDefault();

  const selectedDays = Array.from(elements.habitForm.querySelectorAll("input[name='days']:checked")).map((input) => Number(input.value));
  if (selectedDays.length === 0) {
    showToast("Bitte wähle mindestens einen Wiederholungstag.");
    return;
  }

  const habitData = {
    title: elements.habitTitle.value.trim(),
    description: elements.habitDescription.value.trim(),
    category: elements.habitCategory.value,
    xp: clamp(Number(elements.habitXp.value) || 10, 5, 50),
    daysOfWeek: selectedDays,
  };

  if (!habitData.title) {
    showToast("Bitte gib einen Titel ein.");
    return;
  }

  const habitId = elements.habitId.value;
  if (habitId) {
    state.habits = state.habits.map((habit) => (habit.id === habitId ? { ...habit, ...habitData, updatedAt: new Date().toISOString() } : habit));
    showToast("Habit wurde aktualisiert.");
  } else {
    state.habits.unshift({
      id: createId(),
      ...habitData,
      completedDates: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
    showToast("Habit wurde erstellt.");
  }

  saveState();
  closeHabitModal();
  render();
}

function toggleToday(habitId) {
  const today = getTodayKey();
  state.habits = state.habits.map((habit) => {
    if (habit.id !== habitId) return habit;
    if (!habit.daysOfWeek.includes(new Date().getDay())) return habit;

    const alreadyDone = habit.completedDates.includes(today);
    const completedDates = alreadyDone
      ? habit.completedDates.filter((date) => date !== today)
      : Array.from(new Set([...habit.completedDates, today])).sort();

    return { ...habit, completedDates, updatedAt: new Date().toISOString() };
  });

  saveState();
  render();
  showToast("Fortschritt gespeichert.");
}

function deleteHabit(habitId) {
  const habit = state.habits.find((item) => item.id === habitId);
  if (!habit) return;

  const confirmed = window.confirm(`Habit «${habit.title}» wirklich löschen?`);
  if (!confirmed) return;

  state.habits = state.habits.filter((item) => item.id !== habitId);
  saveState();
  render();
  showToast("Habit wurde gelöscht.");
}

function setRoute(route, updateHash = true) {
  activeRoute = isValidRoute(route) ? route : "dashboard";
  document.querySelectorAll(".view").forEach((view) => view.classList.remove("is-active"));
  const targetView = document.querySelector(`#${activeRoute}View`);
  if (targetView) targetView.classList.add("is-active");
  updateRouteButtons();
  if (updateHash) window.history.replaceState(null, "", `#${activeRoute}`);
}

function isValidRoute(route) {
  return ["dashboard", "stats", "badges", "guide"].includes(route);
}

function updateRouteButtons() {
  document.querySelectorAll(".nav-tab").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.route === activeRoute);
  });
}

function updateFilterButtons() {
  document.querySelectorAll(".filter").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.filter === activeFilter);
  });
}

function seedDemoData() {
  const confirmed = state.habits.length === 0 || window.confirm("Demo-Daten laden? Bestehende Habits werden ersetzt.");
  if (!confirmed) return;

  const today = new Date();
  const daysAgo = (amount) => {
    const date = new Date(today);
    date.setDate(today.getDate() - amount);
    return toDateKey(date);
  };

  state = {
    createdAt: new Date().toISOString(),
    version: 2,
    habits: [
      {
        id: "demo-1",
        title: "20 Minuten spazieren",
        description: "Kurze Bewegung nach der Arbeit, um den Kopf frei zu bekommen.",
        category: "Fitness",
        xp: 10,
        daysOfWeek: dayOrder,
        completedDates: [0, 1, 2, 3, 5, 6, 8, 10, 12].map(daysAgo),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: "demo-2",
        title: "10 Minuten lesen",
        description: "Jeden Tag ein kleines Lernziel erreichen.",
        category: "Lernen",
        xp: 10,
        daysOfWeek: [1, 2, 3, 4, 5],
        completedDates: [0, 1, 2, 4, 7, 9, 11, 14, 16].map(daysAgo),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: "demo-3",
        title: "Wasser trinken",
        description: "Bewusst über den Tag verteilt genug trinken.",
        category: "Gesundheit",
        xp: 5,
        daysOfWeek: dayOrder,
        completedDates: [0, 2, 3, 4, 6, 8, 9, 13, 15, 18].map(daysAgo),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: "demo-4",
        title: "5 Minuten Planung",
        description: "Kurz klären, was heute wirklich wichtig ist.",
        category: "Produktivität",
        xp: 15,
        daysOfWeek: [1, 2, 3, 4, 5],
        completedDates: [0, 1, 3, 4, 7, 8, 10, 14].map(daysAgo),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
  };

  saveState();
  render();
  showToast("Demo-Daten wurden geladen.");
}

function exportData() {
  const data = JSON.stringify(state, null, 2);
  const blob = new Blob([data], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `habithero-export-${getTodayKey()}.json`;
  link.click();
  URL.revokeObjectURL(url);
  showToast("Export wurde erstellt.");
}

function importData(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const reader = new FileReader();
  reader.addEventListener("load", () => {
    try {
      const parsed = JSON.parse(String(reader.result));
      const imported = normaliseState(parsed);
      state = imported;
      saveState();
      render();
      showToast("Daten wurden importiert.");
    } catch (error) {
      console.warn(error);
      showToast("Import fehlgeschlagen. Bitte prüfe die JSON-Datei.");
    } finally {
      event.target.value = "";
    }
  });
  reader.readAsText(file);
}

function resetData() {
  const confirmed = window.confirm("Alle lokal gespeicherten HabitHero-Daten löschen?");
  if (!confirmed) return;
  state = { habits: [], createdAt: new Date().toISOString(), version: 2 };
  localStorage.removeItem(STORAGE_KEY);
  localStorage.removeItem(LEGACY_STORAGE_KEY);
  render();
  showToast("Daten wurden zurückgesetzt.");
}

function showToast(message) {
  clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.classList.add("is-visible");
  toastTimer = setTimeout(() => elements.toast.classList.remove("is-visible"), 2600);
}

function dueToday(habits) {
  const todayDay = new Date().getDay();
  return habits.filter((habit) => habit.daysOfWeek.includes(todayDay));
}

function firstOpenHabitToday() {
  return dueToday(state.habits).find((habit) => !isCompletedToday(habit));
}

function isCompletedToday(habit) {
  return habit.completedDates.includes(getTodayKey());
}

function totalCompletions(habits) {
  return habits.reduce((sum, habit) => sum + habit.completedDates.length, 0);
}

function totalXp(habits) {
  return habits.reduce((sum, habit) => sum + habit.completedDates.length * Number(habit.xp || 10), 0);
}

function levelFromXp(xp) {
  return Math.floor(xp / 100) + 1;
}

function globalCompletionRate(dayCount) {
  const days = getLastNDays(dayCount);
  let due = 0;
  let done = 0;

  days.forEach((dateKey) => {
    state.habits.forEach((habit) => {
      if (habit.daysOfWeek.includes(parseDateKey(dateKey).getDay())) {
        due += 1;
        if (habit.completedDates.includes(dateKey)) done += 1;
      }
    });
  });

  return { due, done, percent: due === 0 ? 0 : Math.round((done / due) * 100) };
}

function habitCompletionStats(habit, dayCount) {
  const days = getLastNDays(dayCount);
  const dueDays = days.filter((date) => habit.daysOfWeek.includes(parseDateKey(date).getDay()));
  const doneDays = dueDays.filter((date) => habit.completedDates.includes(date));
  return {
    due: dueDays.length,
    done: doneDays.length,
    percent: dueDays.length === 0 ? 0 : Math.round((doneDays.length / dueDays.length) * 100),
  };
}

function habitSuccessRate(habit, dayCount) {
  return habitCompletionStats(habit, dayCount).percent;
}

function globalStreak(habits) {
  const completedDates = new Set(habits.flatMap((habit) => habit.completedDates));
  let date = new Date();
  let streak = 0;

  if (!completedDates.has(toDateKey(date))) date.setDate(date.getDate() - 1);

  while (completedDates.has(toDateKey(date))) {
    streak += 1;
    date.setDate(date.getDate() - 1);
  }

  return streak;
}

function maxGlobalStreak(habits) {
  const uniqueDates = Array.from(new Set(habits.flatMap((habit) => habit.completedDates))).sort();
  if (uniqueDates.length === 0) return 0;

  let max = 1;
  let current = 1;

  for (let index = 1; index < uniqueDates.length; index += 1) {
    const previous = parseDateKey(uniqueDates[index - 1]);
    const currentDate = parseDateKey(uniqueDates[index]);
    previous.setDate(previous.getDate() + 1);

    if (toDateKey(previous) === toDateKey(currentDate)) {
      current += 1;
      max = Math.max(max, current);
    } else {
      current = 1;
    }
  }

  return max;
}

function currentHabitStreak(habit) {
  const completedDates = new Set(habit.completedDates);
  let date = new Date();
  let streak = 0;

  if (!completedDates.has(toDateKey(date))) date.setDate(date.getDate() - 1);

  while (completedDates.has(toDateKey(date))) {
    streak += 1;
    date.setDate(date.getDate() - 1);
  }

  return streak;
}

function dueHabitsOnDate(dateKey) {
  const day = parseDateKey(dateKey).getDay();
  return state.habits.filter((habit) => habit.daysOfWeek.includes(day));
}

function completionsOnDate(dateKey) {
  return state.habits.reduce((sum, habit) => sum + (habit.completedDates.includes(dateKey) ? 1 : 0), 0);
}

function getCurrentWeekDays() {
  const today = new Date();
  const currentDay = today.getDay();
  const mondayOffset = currentDay === 0 ? -6 : 1 - currentDay;
  const monday = new Date(today);
  monday.setDate(today.getDate() + mondayOffset);

  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(monday);
    date.setDate(monday.getDate() + index);
    return {
      key: toDateKey(date),
      label: dayLabels[date.getDay()],
      longLabel: formatDateShort(date),
    };
  });
}

function getLastNDays(count) {
  return Array.from({ length: count }, (_, index) => {
    const date = new Date();
    date.setDate(date.getDate() - (count - index - 1));
    return toDateKey(date);
  });
}

function getTodayKey() {
  return toDateKey(new Date());
}

function toDateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function parseDateKey(dateKey) {
  return new Date(`${dateKey}T12:00:00`);
}

function formatDateShort(date) {
  return `${String(date.getDate()).padStart(2, "0")}.${String(date.getMonth() + 1).padStart(2, "0")}.`;
}

function formatDays(days) {
  if (days.length === 7) return ["Täglich"];
  return dayOrder.filter((day) => days.includes(day)).map((day) => dayLabels[day]);
}

function heatLevel(percent, due) {
  if (due === 0) return 0;
  if (percent >= 100) return 4;
  if (percent >= 67) return 3;
  if (percent >= 34) return 2;
  if (percent > 0) return 1;
  return 0;
}

function motivationText(progress, dueCount) {
  if (dueCount === 0) return "Heute ist kein Habit fällig.";
  if (progress === 100) return "Stark. Alle heutigen Habits erledigt.";
  if (progress >= 67) return "Fast geschafft. Nur noch ein kleiner Schritt.";
  if (progress >= 34) return "Guter Fortschritt. Bleib dran.";
  if (progress > 0) return "Der Anfang ist gemacht.";
  return "Starte mit einem kleinen Schritt.";
}

function createId() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID();
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
