/* Javascript for running statistics on the WeeWX registration system */

/* Author: Tom Keffer 2024 */

async function onChangeReport(report_name) {
    if (['python_info', 'weewx_info', 'entry_path',
        'config_path', 'platform_info'].includes(report_name)) {
        // These reports can be optionally consolidated. Activate the dropdown list
        document.getElementById('select_consolidate').disabled = false;
    } else {
        // Other reports do not offer consolidation. Deactivate the dropdown list...
        document.getElementById('select_consolidate').disabled = true;
        // ... then run the given report
        await runReport(report_name, false);
    }
}

async function onChangeConsolidate(consolidate) {
    // Convert text "yes" and "no" into booleans
    consolidate = consolidate === 'yes';
    // Retrieve the report to be run...
    const report_name = document.getElementById('select_report').value;
    // ... then run it
    await runReport(report_name, consolidate);
}

async function runReport(info_type, consolidate) {
    // Run a report for the specified information type

    const SELECT_REPORT = document.getElementById('select_report');
    // get the index of the selected option
    const selectedIndex = SELECT_REPORT.selectedIndex;
    // Get the corresponding value. It will be used for the plot title.
    const selectedValue = SELECT_REPORT.options[selectedIndex].text;

    // Display something blinking to distract the user
    const INFO_PLOT = document.getElementById('info_plot');
    INFO_PLOT.innerHTML = "<h1 class='blink_text'>Please wait...</h1>";

    const results = await getData(info_type, consolidate);
    let data_set = [];
    for (let key in results) {
        data_set.push({
                          type: "scatter",
                          mode: "lines",
                          name: key,
                          x: results[key][0].map((t) => new Date(t * 1000)),
                          y: results[key][1],
                          connectgaps: false,
                      });
    }
    // Shut off the blinking text and replace with the plot.
    INFO_PLOT.innerHTML = "";
    Plotly.newPlot(INFO_PLOT, data_set, {title: selectedValue});
}

async function getData(info_type, consolidate) {
    // Fetch the data from the API server
    let stats_url = '/api/v2/stats/' + info_type;
    // Add a consolidation parameter if requested
    if (consolidate) {
        stats_url += '?consolidate=1';
    }
    try {
        const resp = await fetch(stats_url);
        return await resp.json();
    } catch (error) {
        console.log(error);
    }
}
