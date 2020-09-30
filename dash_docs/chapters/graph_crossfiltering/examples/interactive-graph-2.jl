using CSV, DataFrames, Dash, DashHtmlComponents, DashCoreComponents
using PlotlyJS


url = "https://plotly.github.io/datasets/country_indicators.csv"
download(url, "country-indicators.csv")
df = DataFrame(CSV.File("country-indicators.csv"))

dropmissing!(df)

available_indicators = unique(df[:, "Indicator Name"])
years = unique(df[:, "Year"])

app = dash()

app.layout = html_div() do
    html_div(
        children = [
            html_div(
                children = [
                    dcc_dropdown(
                        id = "crossfilter-xaxis-column",
                        options = [
                            (label = i, value = i)
                            for i in available_indicators
                        ],
                        value = "Fertility rate, total (births per woman)",
                    ),
                    dcc_radioitems(
                        id = "crossfilter-xaxis-type",
                        options = [
                            (label = i, value = i) for i in ["linear", "log"]
                        ],
                        value = "linear",
                    ),
                ],
                style = (width = "49%", display = "inline-block"),
            ),
            html_div(
                children = [
                    dcc_dropdown(
                        id = "crossfilter-yaxis-column",
                        options = [
                            (label = i, value = i)
                            for i in available_indicators
                        ],
                        value = "Life expectancy at birth, total (years)",
                    ),
                    dcc_radioitems(
                        id = "crossfilter-yaxis-type",
                        options = [
                            (label = i, value = i) for i in ["linear", "log"]
                        ],
                        value = "linear",
                    ),
                ],
                style = (
                    width = "49%",
                    float = "right",
                    display = "inline-block",
                ),
            ),
        ],
        style = (
            borderBottom = "thin lightgrey solid",
            backgroundColor = "rgb(250, 250, 250)",
            padding = "10px 5px",
        ),
    ),
    html_div(
        children = [
            dcc_graph(id = "crossfilter-indicator-scatter"),
            dcc_slider(
                id = "crossfilter-year-slider",
                min = minimum(years),
                max = maximum(years),
                marks = Dict([Symbol(v) => Symbol(v) for v in years]),
                value = minimum(years),
                step = nothing,
            ),
        ],
        style = (
            width = "49%",
            display = "inline-block"
        ),
    ),
    html_div(
        children = [
            dcc_graph(id = "x-time-series"),
            dcc_graph(id = "y-time-series"),
        ],
        style = (width = "49%", display = "inline-block"),
    )
end

callback!(
    app,
    Output("crossfilter-indicator-scatter", "figure"),
    Input("crossfilter-xaxis-column", "value"),
    Input("crossfilter-yaxis-column", "value"),
    Input("crossfilter-xaxis-type", "value"),
    Input("crossfilter-yaxis-type", "value"),
    Input("crossfilter-year-slider", "value"),
) do xaxis_column_name, yaxis_column_name, xaxis_type, yaxis_type, year_slider_value

    dff = df[df.Year.==year_slider_value, :]

    return Plot(
        dff[dff[Symbol("Indicator Name")] .== xaxis_column_name, :Value],
        dff[dff[Symbol("Indicator Name")] .== yaxis_column_name, :Value],
        Layout(
            xaxis_type = xaxis_type == "Linear" ? "linear" : "log",
            xaxis_title = xaxis_column_name,
            yaxis_title = yaxis_column_name,
            yaxis_type = yaxis_type == "Linear" ? "linear" : "log",
            hovermode = "closest",
            height = 450,
        ),
        kind = "scatter",
        text = dff[
            dff[Symbol("Indicator Name")] .== yaxis_column_name,
            Symbol("Country Name"),
        ],
        customdata = dff[
            dff[Symbol("Indicator Name")] .== yaxis_column_name,
            Symbol("Country Name"),
        ],
        mode = "markers",
        marker_size = 15,
        marker_opacity = 0.5,
        marker_line_width = 0.5,
        marker_line_color = "white",
    )
end

function create_time_series(dff, axis_type, title)
    Plot(
        dff[:, :Year],
        dff[:, :Value],
        Layout(
            yaxis_type = axis_type == "Linear" ? "linear" : "log",
            xaxis_showgrid = false,
            annotations = [attr(
                x = 0,
                y = 0.85,
                xanchor = "left",
                yanchor = "bottom",
                xref = "paper",
                yref = "paper",
                showarrow = false,
                align = "left",
                bgcolor = "rgba(255, 255, 255, 0.5)",
                text = title,
            )],
            height = 225,
        ),
        mode = "lines+markers",
    )
end

callback!(
    app,
    Output("x-time-series", "figure"),
    Input("crossfilter-indicator-scatter", "hoverData"),
    Input("crossfilter-xaxis-column", "value"),
    Input("crossfilter-xaxis-type", "value"),
) do hover_data, xaxis_column_name, axis_type
    country_name = isnothing(hover_data) ? "" : hover_data.points[1].customdata
    dff = df[df[:, Symbol("Country Name")].==country_name, :]
    dff = dff[dff[:, Symbol("Indicator Name")].==xaxis_column_name, :]
    title = "<b>$(country_name)</b><br>$(xaxis_column_name)"
    return create_time_series(dff, axis_type, title)

end

callback!(
    app,
    Output("y-time-series", "figure"),
    Input("crossfilter-indicator-scatter", "hoverData"),
    Input("crossfilter-yaxis-column", "value"),
    Input("crossfilter-yaxis-type", "value"),
) do hover_data, yaxis_column_name, axis_type
    country_name = isnothing(hover_data) ? "" : hover_data.points[1].customdata
    dff = df[df[:, Symbol("Country Name")].==country_name, :]
    dff = dff[dff[:, Symbol("Indicator Name")].==yaxis_column_name, :]
    return create_time_series(dff, axis_type, yaxis_column_name)
end

run_server(app, "0.0.0.0", 8000, debug = true)