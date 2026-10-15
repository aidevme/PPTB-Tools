// audit-slide-layout.js
// Reveal.js editorial-deck layout audit. Flags content slides where:
//   - OVERFLOW: content extends past the body-region's bottom (collides with
//     or clips behind the footer)
//   - WHITESPACE: content fills less than (slideH - 160px) of the available
//     body-region area, signalling under-used real estate
//   - WORKFLOW_WRAP: a .workflow process flow spans more than one row
//
// Sparse-by-design slide types (.divider / .title-slide / .stat / .closing,
// plus legacy .section-divider) are excluded from WHITESPACE checks — they
// intentionally use generous empty space.
//
// MEASUREMENT MODEL — The editorial layout uses a flex column inside the
// section: padding-top → .body-region (flex:1) → .footer. We measure
// (last-child-bottom − first-child-top) inside .body-region against the
// region's clientHeight (minus its own padding). This correctly catches
// content that overflows past the footer line, which the old
// `section.scrollHeight` model missed (sections have overflow:hidden, so
// scrollHeight saturates at the slide height).
//
// HOW TO RUN
// ──────────
// This file exports a single async arrow-function expression. Run it via a
// small Node wrapper that drives Playwright directly — playwright-cli's `eval`
// bridge has serialization issues for scripts of this size. Recommended runner:
//
//   // run-audit.js (next to the deck)
//   const { chromium } = require('playwright');
//   const fs = require('fs');
//   (async () => {
//     const browser = await chromium.launch();
//     const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
//     await page.goto('file://' + require('path').resolve(process.argv[2]));
//     await page.waitForFunction(() => window.Reveal && window.Reveal.isReady && window.Reveal.isReady());
//     const auditFn = fs.readFileSync(__dirname + '/audit-slide-layout.js', 'utf8');
//     const problems = await page.evaluate(`(${auditFn})()`);
//     console.log(JSON.stringify(problems, null, 2));
//     await browser.close();
//     process.exit(problems.length ? 1 : 0);
//   })();
//
// Then: `node run-audit.js path/to/deck.html`
//
// Returns an array of problem slides. Empty array = deck passes.

/* eslint-env browser */
async ({ overflowThresholdPx = 10, whitespaceThresholdPx = 160 } = {}) => {
    const cfg = Reveal.getConfig();
    const slideH = cfg.height;
    const slideW = cfg.width;
    const sections = document.querySelectorAll('.reveal .slides > section');
    const problems = [];

    for (let i = 0; i < sections.length; i++) {
        Reveal.slide(i);
        await new Promise(r => setTimeout(r, 40)); // let layout settle

        const s = sections[i];

        // Sparse-by-design types — skip WHITESPACE check.
        const isSparse = s.classList.contains('section-divider')
            || s.classList.contains('title-slide')
            || s.classList.contains('divider')
            || s.classList.contains('stat')
            || s.classList.contains('closing');

        // Find the measurement target — prefer the editorial .body-region,
        // fall back to the section itself for legacy decks.
        const bodyRegion = s.querySelector('.body-region');
        const target = bodyRegion || s;

        // Compute content height: bottom of last child minus top of first child.
        // This catches overflow past the body-region even when overflow:hidden
        // would clip section.scrollHeight to the slide height.
        const kids = Array.from(target.children).filter(c => {
            const cs = window.getComputedStyle(c);
            return cs.display !== 'none' && cs.position !== 'absolute';
        });
        let contentH = 0;
        if (kids.length) {
            const tops = kids.map(c => c.getBoundingClientRect().top);
            const bottoms = kids.map(c => c.getBoundingClientRect().bottom);
            contentH = Math.max(...bottoms) - Math.min(...tops);
        }

        // Available area inside the measurement target.
        let availableH;
        if (bodyRegion) {
            const cs = window.getComputedStyle(bodyRegion);
            availableH = bodyRegion.clientHeight
                - parseFloat(cs.paddingTop)
                - parseFloat(cs.paddingBottom);
        } else {
            // Legacy: measure against the slide height directly.
            availableH = slideH;
        }

        const overflow = Math.max(0, contentH - availableH);
        const whitespace = Math.max(0, availableH - contentH);
        const wsThreshold = isSparse ? Infinity : whitespaceThresholdPx;

        // Detect wrapped .workflow (must fit on one row).
        let workflowWrapped = false;
        let workflowOverflowX = false;
        const workflows = s.querySelectorAll('.workflow');
        for (const wf of workflows) {
            if (wf.scrollWidth > slideW + 2) workflowOverflowX = true;
            const tops = new Set(Array.from(wf.children).map(c => Math.round(c.getBoundingClientRect().top)));
            if (tops.size > 1) workflowWrapped = true;
        }

        // Detect content that has clipped behind the footer (visual collision).
        // The footer's top should be >= last meaningful child's bottom.
        let footerCollision = false;
        const footer = s.querySelector('.footer');
        if (footer && bodyRegion) {
            const footerTop = footer.getBoundingClientRect().top;
            const lastChildBottom = kids.length ? Math.max(...kids.map(c => c.getBoundingClientRect().bottom)) : 0;
            if (lastChildBottom > footerTop + 2) footerCollision = true;
        }

        let status = 'ok';
        if (overflow > overflowThresholdPx || footerCollision) status = 'OVERFLOW';
        else if (whitespace > wsThreshold) status = 'WHITESPACE';
        if (workflowWrapped || workflowOverflowX) {
            status = status === 'ok' ? 'WORKFLOW_WRAP' : status + '+WORKFLOW_WRAP';
        }

        if (status !== 'ok') {
            problems.push({
                index: i,
                title: (s.querySelector('h1,h2,h3')?.textContent || '').trim().slice(0, 60),
                contentH: Math.round(contentH),
                availableH: Math.round(availableH),
                overflowPx: Math.round(overflow),
                whitespacePx: Math.round(whitespace),
                isSparse,
                footerCollision,
                workflowWrapped,
                workflowOverflowX,
                status
            });
        }
    }

    return problems;
}
