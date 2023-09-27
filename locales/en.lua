local Translations = {
    error = {
        you_already_have_objects_down = 'You already have %{MaxPlantCount} objects down',
    },
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
