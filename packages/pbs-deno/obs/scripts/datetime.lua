obs = obslua

-- Structure to store settings for each text source
source_settings = {
    {name = "", separator = ", ", show_time = true, show_am_pm = false, show_weekday = false, show_calendar_week = false, show_date = false, date_format = "DD.MM.YYYY"},
    {name = "", separator = ", ", show_time = true, show_am_pm = false, show_weekday = false, show_calendar_week = false, show_date = false, date_format = "DD.MM.YYYY"},
    {name = "", separator = ", ", show_time = true, show_am_pm = false, show_weekday = false, show_calendar_week = false, show_date = false, date_format = "DD.MM.YYYY"},
    {name = "", separator = ", ", show_time = true, show_am_pm = false, show_weekday = false, show_calendar_week = false, show_date = false, date_format = "DD.MM.YYYY"},
    {name = "", separator = ", ", show_time = true, show_am_pm = false, show_weekday = false, show_calendar_week = false, show_date = false, date_format = "DD.MM.YYYY"}
}

-- Set the locale to English
os.setlocale("en_US.UTF-8")

-- Variable to track the last update time
last_update_time = 0
update_interval = 20 -- Update interval set to 20 seconds

function script_description()
    return "Allows updating up to five text sources with individual settings for time, AM/PM format, date, weekday, and calendar week every 20 seconds. Updating every 20 seconds saves resources."
end

function script_update(settings)
    for i = 1, 5 do
        source_settings[i].name = obs.obs_data_get_string(settings, "source" .. i)
        source_settings[i].separator = obs.obs_data_get_string(settings, "separator" .. i)
        if source_settings[i].separator == "" then
            source_settings[i].separator = " "
        end
        source_settings[i].show_time = obs.obs_data_get_bool(settings, "show_time" .. i)
        source_settings[i].show_am_pm = obs.obs_data_get_bool(settings, "show_am_pm" .. i)
        source_settings[i].show_weekday = obs.obs_data_get_bool(settings, "show_weekday" .. i)
        source_settings[i].show_calendar_week = obs.obs_data_get_bool(settings, "show_calendar_week" .. i)
        source_settings[i].show_date = obs.obs_data_get_bool(settings, "show_date" .. i)
        source_settings[i].date_format = obs.obs_data_get_string(settings, "date_format" .. i)
    end
    -- Trigger immediate update and restart timer
    last_update_time = 0
    script_tick(0)
end

function script_properties()
    local props = obs.obs_properties_create()
    
    for i = 1, 5 do
        local p = obs.obs_properties_add_list(props, "source" .. i, "Source " .. i, obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
        add_sources(p)
        obs.obs_properties_add_text(props, "separator" .. i, "Separator", obs.OBS_TEXT_DEFAULT)
        obs.obs_properties_add_bool(props, "show_time" .. i, "Show Time")
        obs.obs_properties_add_bool(props, "show_am_pm" .. i, "Show AM/PM")
        obs.obs_properties_add_bool(props, "show_date" .. i, "Show Date")
        obs.obs_properties_add_bool(props, "show_weekday" .. i, "Show Weekday")
        obs.obs_properties_add_bool(props, "show_calendar_week" .. i, "Show Calendar Week")
        
        local date_format = obs.obs_properties_add_list(props, "date_format" .. i, "Date Format", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        obs.obs_property_list_add_string(date_format, "DD.MM.YYYY", "DD.MM.YYYY")
        obs.obs_property_list_add_string(date_format, "DD MMM YYYY", "DD MMM YYYY")
        obs.obs_property_list_add_string(date_format, "MMM DD, YYYY", "MMM DD, YYYY")
        obs.obs_property_list_add_string(date_format, "YYYY-MM-DD", "YYYY-MM-DD")
        obs.obs_property_list_add_string(date_format, "MM/DD/YYYY", "MM/DD/YYYY")
    end
    return props
end

function add_sources(property)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(property, name, name)
            end
        end
    end
    obs.source_list_release(sources)
end

function script_tick(seconds)
    local current_time = os.time()
    if current_time - last_update_time >= update_interval then
        for i, setting in ipairs(source_settings) do
            update_source(setting.name, setting.separator, setting.show_time, setting.show_am_pm, setting.show_weekday, setting.show_calendar_week, setting.show_date, setting.date_format)
        end
        last_update_time = current_time
    end
end

function get_calendar_week()
    local current_date = os.date("*t")
    local jan1 = os.time{year = current_date.year, month = 1, day = 1}
    local day_of_year = os.date("%j")
    local jan1_weekday = os.date("%w", jan1)
    local week_num = math.ceil((day_of_year + jan1_weekday - 1) / 7)
    return week_num
end

function update_source(source_name, separator, show_time, show_am_pm, show_weekday, show_calendar_week, show_date, date_format)
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        local time_format = "%I:%M"
        local date_format_string = ""

        if date_format == "DD.MM.YYYY" then
            date_format_string = "%d.%m.%Y"
        elseif date_format == "DD MMM YYYY" then
            date_format_string = "%d %b %Y"
        elseif date_format == "MMM DD, YYYY" then
            date_format_string = "%b %d, %Y"
        elseif date_format == "YYYY-MM-DD" then
            date_format_string = "%Y-%m-%d"
        elseif date_format == "MM/DD/YYYY" then
            date_format_string = "%m/%d/%Y"
        end

        local weekday_format = "%a"

        local components = {}
        if show_calendar_week then
            table.insert(components, "CW " .. get_calendar_week())
        end
        if show_weekday then
            table.insert(components, os.date(weekday_format))
        end
        if show_date then
            table.insert(components, os.date(date_format_string))
        end
        if show_time then
            local time_text = os.date(time_format)
            if show_am_pm then
                time_text = time_text .. " " .. os.date("%p")
            end
            table.insert(components, time_text)
        end

        local text = table.concat(components, separator)

        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end