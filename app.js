(() => {
  "use strict";

  const $ = (selector) => document.querySelector(selector);
  const config = window.UNKNOWN_CONFIG || {};
  const isConfigured = () =>
    config.supabaseUrl &&
    config.supabaseAnonKey &&
    !config.supabaseUrl.includes("PASTE_") &&
    !config.supabaseAnonKey.includes("PASTE_");

  let supabase = null;
  let authMode = "login";
  let demoMode = false;

  if (isConfigured() && window.supabase?.createClient) {
    supabase = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey);
  }

  const authView = $("#authView");
  const appView = $("#appView");
  const authMessage = $("#authMessage");

  function showMessage(message, type = "info") {
    authMessage.textContent = message;
    authMessage.className = `message ${type}`;
  }

  function toast(message) {
    const node = $("#toast");
    node.textContent = message;
    node.classList.add("show");
    window.setTimeout(() => node.classList.remove("show"), 2800);
  }

  function initials(name) {
    return (name || "U").trim().slice(0, 1).toUpperCase();
  }

  function setAuthMode(mode) {
    authMode = mode;
    const signup = mode === "signup";
    $("#loginTab").classList.toggle("active", !signup);
    $("#signupTab").classList.toggle("active", signup);
    $("#usernameField").classList.toggle("hidden", !signup);
    $("#username").required = signup;
    $("#password").autocomplete = signup ? "new-password" : "current-password";
    $("#authHeading").innerHTML = signup
      ? '<p class="eyebrow">CREATE YOUR IDENTITY</p><h2>Enter the unknown.</h2><p class="muted">Create an account to save your story.</p>'
      : '<p class="eyebrow">WELCOME BACK</p><h2>Enter your world.</h2><p class="muted">Sign in to continue your journey.</p>';
    $("#authSubmit").innerHTML = signup ? 'CREATE ACCOUNT <span>↗</span>' : 'LOG IN <span>↗</span>';
    showMessage("");
  }

  function openDashboard(profile, user) {
    demoMode = !user;
    authView.classList.add("hidden");
    appView.classList.remove("hidden");

    const username = profile?.username || user?.user_metadata?.username || user?.email?.split("@")[0] || "Unknown Player";
    const avatar = initials(username);
    $("#welcomeName").textContent = username;
    $("#profileName").textContent = username;
    $("#sideUsername").textContent = username;
    $("#sideAvatar").textContent = avatar;
    $("#topAvatar").textContent = avatar;
    $("#profileAvatar").textContent = avatar;
    $("#accountStatus").textContent = demoMode ? "DEMO PREVIEW" : "CONNECTED";
    $("#statScore").textContent = profile?.total_score ?? "0";
    $("#statEvents").textContent = profile?.events_completed ?? "0";
    $("#statMysteries").textContent = profile?.mysteries_solved ?? "0";
  }

  async function loadProfile(user) {
    const { data, error } = await supabase
      .from("profiles")
      .select("username,total_score,events_completed,mysteries_solved")
      .eq("id", user.id)
      .maybeSingle();

    if (error) {
      console.error("Profile load error:", error);
      toast("Signed in, but profile data could not be loaded.");
    }
    return data || { username: user.user_metadata?.username || user.email?.split("@")[0] };
  }

  async function handleAuth(event) {
    event.preventDefault();
    const email = $("#email").value.trim();
    const password = $("#password").value;
    const username = $("#username").value.trim();
    const submit = $("#authSubmit");

    if (!supabase) {
      showMessage("Supabase is not configured yet. Add your Project URL and anon key to config.js, or use Preview dashboard.", "error");
      return;
    }
    if (authMode === "signup" && !/^[a-zA-Z0-9_]{3,20}$/.test(username)) {
      showMessage("Username must be 3–20 characters and use only letters, numbers or underscores.", "error");
      return;
    }

    submit.disabled = true;
    submit.textContent = authMode === "signup" ? "CREATING ACCOUNT..." : "SIGNING IN...";
    showMessage("");

    try {
      if (authMode === "signup") {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: { data: { username } }
        });
        if (error) throw error;

        if (data.session && data.user) {
          const profile = await loadProfile(data.user);
          openDashboard(profile, data.user);
        } else {
          showMessage("Account created. Check your email to confirm, then log in. If you are testing locally, add your local URL to Supabase Auth redirect settings.", "success");
          setAuthMode("login");
        }
      } else {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        const profile = await loadProfile(data.user);
        openDashboard(profile, data.user);
      }
    } catch (error) {
      showMessage(error.message || "Something went wrong. Please try again.", "error");
    } finally {
      submit.disabled = false;
      submit.innerHTML = authMode === "signup" ? 'CREATE ACCOUNT <span>↗</span>' : 'LOG IN <span>↗</span>';
    }
  }

  async function boot() {
    document.querySelectorAll("[data-year]").forEach(el => el.textContent = new Date().getFullYear());
    $("#loginTab").addEventListener("click", () => setAuthMode("login"));
    $("#signupTab").addEventListener("click", () => setAuthMode("signup"));
    $("#authForm").addEventListener("submit", handleAuth);

    $("#demoButton").addEventListener("click", () => {
      openDashboard({ username: "ShadowHunter", total_score: 8450, events_completed: 18, mysteries_solved: 4 }, null);
      toast("Demo preview opened. Connect Supabase for real accounts.");
    });

    $("#logoutButton").addEventListener("click", async () => {
      if (supabase && !demoMode) {
        const { error } = await supabase.auth.signOut();
        if (error) toast(error.message);
      }
      demoMode = false;
      appView.classList.add("hidden");
      authView.classList.remove("hidden");
      $("#authForm").reset();
      setAuthMode("login");
    });

    $("#startButton").addEventListener("click", () => toast("Phase 2 will add the playable story and question engine."));
    $("#continueButton").addEventListener("click", () => toast("No saved journey yet. Story gameplay arrives in Phase 2."));
    document.querySelectorAll(".nav-item[data-page]").forEach(button => {
      button.addEventListener("click", () => {
        document.querySelectorAll(".nav-item[data-page]").forEach(item => item.classList.remove("active"));
        button.classList.add("active");
        const page = button.dataset.page;
        if (page === "dashboard") return;
        if (page === "profile") toast("Profile settings will be added in a later Phase.");
        else toast(`${button.textContent.trim()} will be available in a later Phase.`);
        if (window.innerWidth <= 850) $("#sidebar").classList.remove("sidebar-open");
      });
    });
    $("#mobileMenu").addEventListener("click", () => $("#sidebar").classList.toggle("sidebar-open"));

    if (supabase) {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const profile = await loadProfile(session.user);
        openDashboard(profile, session.user);
      }
      supabase.auth.onAuthStateChange(async (_event, session) => {
        if (session?.user && authView.classList.contains("hidden") === false) {
          const profile = await loadProfile(session.user);
          openDashboard(profile, session.user);
        }
      });
    } else {
      showMessage("Connect Supabase to enable real registration and login. You can preview the dashboard meanwhile.", "info");
    }
  }

  boot();
})();
