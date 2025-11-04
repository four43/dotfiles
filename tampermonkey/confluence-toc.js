// ==UserScript==
// @name         Confluence Floating ToC
// @namespace    http://tampermonkey.net/
// @version      1.3
// @description  Adds a floating, hierarchical table of contents to Confluence pages.
// @author       Gemini
// @match        https://*.atlassian.net/wiki/spaces/*
// @grant        GM_addStyle
// @grant        GM_getValue
// @grant        GM_setValue
// ==/UserScript==

(function() {
    'use strict';

    const TOC_PANEL_ID = 'gemini-floating-toc-panel';
    const TOC_BUTTON_ID = 'gemini-floating-toc-button';
    const TOC_LINKS_CONTAINER_ID = 'gemini-toc-links-container';
    const STORAGE_KEY = 'gemini-toc-visible';
    
    // --- Global variables to hold our created elements and observer ---
    // We create these once and re-attach them if they get removed.
    let tocPanel = null;
    let tocButton = null;
    let contentObserver = null;
    let lastObserverTarget = null;
    let isScrollListenerAttached = false;

    // --- 1. Add All CSS Styles ---
    // (This only needs to run once at the start)
    GM_addStyle(`
        /* 1. Make the main layout a flex container */
        #layout-main-wrapper {
            display: flex;
            flex-direction: row;
            position: relative;
        }

        /* 2. Style the ToC Panel */
        #${TOC_PANEL_ID} {
            width: 280px;
            flex-shrink: 0;
            height: calc(100vh - 60px); /* Adjust 60px for your header height */
            position: sticky;
            top: 60px; /* Match header height */
            overflow-y: auto;
            padding: 20px 15px;
            margin-left: 24px;
            background: var(--ds-surface-overlay, #FFFFFF);
            border-radius: 0px;
            border: 1px solid var(--ds-border, #0B120E24);
            transition: all 0.3s ease-in-out;
            font-size: 13px;
            box-sizing: border-box;
            opacity: 1;
        }

        /* 3. Hidden State for ToC */
        #${TOC_PANEL_ID}.hidden {
            width: 0;
            padding: 0;
            margin: 0;
            border: none;
            overflow: hidden;
            opacity: 0;
        }

        /* 4. ToC Header */
        #${TOC_PANEL_ID} h4 {
            margin-top: 0;
            margin-bottom: 10px;
            padding-bottom: 10px;
            border-bottom: 1px solid var(--ds-border, #0B120E24);
            color: var(--ds-text, #292A2E);
            font-size: 16px;
            font-weight: 600;
            white-space: nowrap;
        }

        /* 5. ToC Links */
        #${TOC_LINKS_CONTAINER_ID} a {
            display: block;
            padding: 5px 8px;
            text-decoration: none !important;
            color: var(--ds-link, #1868DB) !important;
            border-radius: 3px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            transition: background-color 0.2s ease;
        }

        #${TOC_LINKS_CONTAINER_ID} a:hover {
            background-color: var(--ds-background-neutral-hovered, #F0F1F2);
            color: var(--ds-link-pressed, #1558BC) !important;
        }

        /* 6. Active Link Highlighting */
        #${TOC_LINKS_CONTAINER_ID} a.active {
            background-color: var(--ds-background-selected, #E9F2FE);
            color: var(--ds-link-pressed, #1558BC) !important;
            font-weight: 600;
        }

        /* 7. Hierarchy Padding */
        #${TOC_LINKS_CONTAINER_ID} .toc-h1 { padding-left: 8px; font-weight: 600; }
        #${TOC_LINKS_CONTAINER_ID} .toc-h2 { padding-left: 16px; }
        #${TOC_LINKS_CONTAINER_ID} .toc-h3 { padding-left: 24px; font-size: 12px; }
        #${TOC_LINKS_CONTAINER_ID} .toc-h4 { padding-left: 32px; font-size: 12px; color: var(--ds-text-subtle, #505258); }

        /* 8. Toggle Button */
        #${TOC_BUTTON_ID} {
            background: transparent;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            height: 32px;
            width: 32px;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 0;
            /* Match the fill color of other icons */
            color: var(--ds-icon, #FFF);
        }
        
        #${TOC_BUTTON_ID} svg path {
             /* Use 'currentColor' to inherit the white from the button's color style */
            fill: currentColor !important;
        }

        #${TOC_BUTTON_ID}:hover {
            background-color: var(--ds-top-bar-button-background-hovered, rgba(255, 255, 255, 0.1));
        }

        #${TOC_BUTTON_ID}.active {
            background-color: var(--ds-top-bar-button-selected-background, rgba(255, 255, 255, 0.15));
        }

        /* 9. Responsive: Hide on smaller screens */
        @media (max-width: 1024px) {
            #${TOC_PANEL_ID}, #${TOC_BUTTON_ID} {
                display: none;
            }
        }
    `);

    // --- 2. Create/Get Panel Element ---
    // Creates the panel in memory once, so we can re-attach it later.
    function getTocPanel() {
        if (!tocPanel) {
            console.log('Floating ToC: Creating panel element in memory.');
            tocPanel = document.createElement('div');
            tocPanel.id = TOC_PANEL_ID;
            tocPanel.innerHTML = `<h4>Table of Contents</h4><div id="${TOC_LINKS_CONTAINER_ID}"></div>`;
        }
        return tocPanel;
    }

    // --- 3. Create/Get Button Element ---
    // Creates the button in memory once, so we can re-attach it later.
    function getTocButton() {
        if (!tocButton) {
            console.log('Floating ToC: Creating button element in memory.');
            tocButton = document.createElement('button');
            tocButton.id = TOC_BUTTON_ID;
            tocButton.title = 'Toggle Table of Contents';
            tocButton.innerHTML = `
                <svg xmlns="http://www.w3.org/2000/svg" width="20px" height="20px" viewBox="0 0 24 24">
                    <path fill="currentColor" d="M11.5 14.8V9.2q0-.35-.3-.475t-.55.125L8.2 11.3q-.3.3-.3.7t.3.7l2.45 2.45q.25.25.55.125t.3-.475M5 21q-.825 0-1.412-.587T3 19V5q0-.825.588-1.412T5 3h14q.825 0 1.413.588T21 5v14q0 .825-.587 1.413T19 21zm9-2V5H5v14z"/>
                </svg>
            `;

            // Add click listener ONCE
            tocButton.addEventListener('click', () => {
                const panel = getTocPanel(); // Get the panel
                const isCurrentlyVisible = !panel.classList.contains('hidden');
                toggleTOC(panel, tocButton, !isCurrentlyVisible);
            });
        }
        return tocButton;
    }

    // --- 4. Populate the ToC Panel ---
    function populateTOC() {
        const panel = getTocPanel();
        const linksContainer = panel.querySelector(`#${TOC_LINKS_CONTAINER_ID}`);
        if (!linksContainer) return;

        linksContainer.innerHTML = '';
        const headings = document.querySelectorAll('#main-content.wiki-content h1, #main-content.wiki-content h2, #main-content.wiki-content h3, #main-content.wiki-content h4');
        
        if (headings.length === 0) {
            linksContainer.innerHTML = 'No headings found on this page.';
            return;
        }

        headings.forEach(heading => {
            if (!heading.id) {
                return; // Skip headings without IDs
            }
            
            const link = document.createElement('a');
            link.href = '#' + heading.id;
            link.textContent = heading.textContent;
            const level = heading.tagName.toLowerCase();
            link.className = 'toc-' + level;
            
            // Smooth scroll
            link.onclick = (e) => {
                e.preventDefault();
                heading.scrollIntoView({ behavior: 'smooth', block: 'start' });
                if (history.pushState) {
                    history.pushState(null, null, '#' + heading.id);
                } else {
                    location.hash = '#' + heading.id;
                }
            };
            
            linksContainer.appendChild(link);
        });
    }

    // --- 5. Toggle Visibility ---
    function toggleTOC(panel, button, isVisible) {
        if (panel) {
            panel.classList.toggle('hidden', !isVisible);
        }
        if (button) {
            button.classList.toggle('active', isVisible);
        }
        GM_setValue(STORAGE_KEY, isVisible);
    }

    // --- 6. Highlight Active Link on Scroll ---
    let scrollTimeout;
    function onScroll() {
        if (scrollTimeout) {
            cancelAnimationFrame(scrollTimeout);
        }

        scrollTimeout = requestAnimationFrame(() => {
            const headings = document.querySelectorAll('#main-content.wiki-content h1[id], #main-content.wiki-content h2[id], #main-content.wiki-content h3[id], #main-content.wiki-content h4[id]');
            const tocLinks = document.querySelectorAll(`#${TOC_LINKS_CONTAINER_ID} a`);
            
            const scrollOffset = 70; // 60px header height + 10px buffer
            let activeHeadingId = null;

            for (let i = headings.length - 1; i >= 0; i--) {
                const heading = headings[i];
                const rect = heading.getBoundingClientRect();
                
                if (rect.top <= scrollOffset) {
                    activeHeadingId = heading.id;
                    break;
                }
            }

            tocLinks.forEach(link => {
                link.classList.toggle('active', link.getAttribute('href') === '#' + activeHeadingId);
            });
        });
    }


    // --- 7. Main "Ensurer" Loop ---
    // This runs periodically to make sure our elements haven't been wiped out by SPA re-renders
    function ensureElements() {
        const mainWrapper = document.querySelector('#layout-main-wrapper');
        const shareRestrictButton = document.querySelector('div[data-vc="share-restrict-and-copy-button"]');
        const contentContainer = document.querySelector('#main-content.wiki-content');

        // Wait for all key elements to be on the page
        if (!mainWrapper || !shareRestrictButton || !contentContainer) {
            console.log('Floating ToC (Ensurer): Waiting for core layout elements...');
            return;
        }

        // --- Ensure Panel ---
        let panel = document.getElementById(TOC_PANEL_ID);
        if (!panel) {
            console.log('Floating ToC (Ensurer): Panel not found. Injecting...');
            panel = getTocPanel(); // Get or create
            mainWrapper.appendChild(panel);
            const savedState = GM_getValue(STORAGE_KEY, true);
            toggleTOC(panel, getTocButton(), savedState); // Toggle will update both
        }

        // --- Ensure Button ---
        let button = document.getElementById(TOC_BUTTON_ID);
        if (!button) {
            console.log('Floating ToC (Ensurer): Button not found. Injecting...');
            const shareButtonContainer = shareRestrictButton.closest('div[data-testid="share-action-container-without-separator"]');
            if (shareButtonContainer && shareButtonContainer.parentElement) {
                const buttonContainer = shareButtonContainer.parentElement;
                button = getTocButton(); // Get or create
                buttonContainer.insertBefore(button, shareButtonContainer);
                const savedState = GM_getValue(STORAGE_KEY, true);
                toggleTOC(getTocPanel(), button, savedState); // Toggle will update both
            } else {
                 console.log('Floating ToC (Ensurer): Could not find share button parent.');
            }
        }
        
        // --- Ensure Observer & Content ---
        // Only attach observer if it's not attached or if the content element has changed
        if (!contentObserver || lastObserverTarget !== contentContainer) {
            console.log('Floating ToC (Ensurer): Attaching observer and populating ToC.');
            
            // Disconnect old one if it exists
            if (contentObserver) {
                contentObserver.disconnect();
            }

            populateTOC();

            let populateDebounce;
            contentObserver = new MutationObserver(() => {
                console.log('Floating ToC (Observer): Content change detected, repopulating.');
                clearTimeout(populateDebounce);
                populateDebounce = setTimeout(populateTOC, 300);
            });
            contentObserver.observe(contentContainer, { childList: true, subtree: true });
            lastObserverTarget = contentContainer;
            
            // Add scroll listener (only needs to be done once)
            if (!isScrollListenerAttached) {
                console.log('Floating ToC (Ensurer): Attaching scroll listener.');
                window.addEventListener('scroll', onScroll, { passive: true });
                isScrollListenerAttached = true;
            }
        }
    }

    // --- 8. Start Everything ---
    console.log('Floating ToC: Starting script...');
    // addGlobalStyles(); // <-- This was the error. Removed it, as styles are added in section 1.
    setInterval(ensureElements, 1000); // Check every second

})();


