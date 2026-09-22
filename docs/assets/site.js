(() => {
  const STORAGE_KEY = "tastewise-theme";
  const root = document.documentElement;

  const applyTheme = (theme) => {
    if (theme === "light" || theme === "dark") {
      root.setAttribute("data-theme", theme);
      root.style.colorScheme = theme;
    } else {
      root.removeAttribute("data-theme");
      root.style.colorScheme = "light dark";
    }
    document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
      const next = resolvedTheme() === "dark" ? "light" : "dark";
      btn.setAttribute("aria-pressed", resolvedTheme() === "dark" ? "true" : "false");
      btn.setAttribute("aria-label", `Switch to ${next} mode`);
    });
  };

  const resolvedTheme = () => {
    const stored = root.getAttribute("data-theme");
    if (stored) return stored;
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  };

  const stored = localStorage.getItem(STORAGE_KEY);
  applyTheme(stored === "light" || stored === "dark" ? stored : null);

  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if (!localStorage.getItem(STORAGE_KEY)) applyTheme(null);
  });

  document.addEventListener("click", (event) => {
    const toggle = event.target.closest("[data-theme-toggle]");
    if (toggle) {
      const next = resolvedTheme() === "dark" ? "light" : "dark";
      localStorage.setItem(STORAGE_KEY, next);
      applyTheme(next);
      return;
    }

    const opener = event.target.closest("[data-nav-open]");
    if (opener) {
      const nav = document.getElementById("site-nav");
      const open = nav?.classList.toggle("is-open");
      opener.setAttribute("aria-expanded", open ? "true" : "false");
      return;
    }

    const copy = event.target.closest("[data-copy]");
    if (copy) {
      const value = copy.getAttribute("data-copy");
      if (!value) return;
      navigator.clipboard.writeText(value).then(() => {
        const original = copy.textContent;
        copy.textContent = "Copied";
        setTimeout(() => {
          copy.textContent = original;
        }, 1200);
      });
    }
  });

  const nav = document.getElementById("site-nav");
  nav?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      nav.classList.remove("is-open");
      document.querySelector("[data-nav-open]")?.setAttribute("aria-expanded", "false");
    });
  });

  const sections = [...document.querySelectorAll("main [id]")];
  const tocLinks = [...document.querySelectorAll(".ds-toc a")];
  if (sections.length && tocLinks.length && "IntersectionObserver" in window) {
    const map = new Map(tocLinks.map((a) => [a.getAttribute("href")?.slice(1), a]));
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          tocLinks.forEach((a) => a.classList.remove("is-active"));
          map.get(entry.target.id)?.classList.add("is-active");
        });
      },
      { rootMargin: "-20% 0px -70% 0px" },
    );
    sections.forEach((section) => io.observe(section));
  }
})();
