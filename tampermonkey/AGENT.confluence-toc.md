# Atlassian Table of Contents

I need to create an in-browser Tampermonkey script. This is a browser (chrome) plugin that runs customer javascript on specific domains.

See their docs here: https://www.tampermonkey.net/documentation.php?locale=en

# Primary Goal
Create a floating table of contents for a cloud Atlassian Confluence Page. This should appear on the right side and float as we scroll. Its should be controllable by a button on the top navigation bar.

# Execution Details

## Table of Contents
To create the table of contents, the script should query the page for all headings and build a hierarchy. A panel should be created on the right side, next to the main page content that floats and scrolls with the content. There is a div, with ID `layout-main-wrapper` which holds the main content. Injecting a child div here that floats should work well. Create a hierarchical display, common to table of contents displays, and has links we can use to jump to the anchors.

## Toggle Button
It should also create a toggle button to turn this feature on and off.

There is a button panel, with a `data-vc` property `share-restrict-and-copy-button`

Use this SVG as the icon in the button:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="20px" height="20px" viewBox="0 0 24 24"><path fill="#fdfdfd" d="M11.5 14.8V9.2q0-.35-.3-.475t-.55.125L8.2 11.3q-.3.3-.3.7t.3.7l2.45 2.45q.25.25.55.125t.3-.475M5 21q-.825 0-1.412-.587T3 19V5q0-.825.588-1.412T5 3h14q.825 0 1.413.588T21 5v14q0 .825-.587 1.413T19 21zm9-2V5H5v14z"/></svg>
```

