# Example View Overrides

These are Tailwind CSS versions of some of ActionAuth's screens, to show what a heavily customized screen can look like. They're for inspiration, not a complete set.

To customize your own screens, start with the generator, which always copies views that match your version of ActionAuth:

```bash
bin/rails generate action_auth:views
```

See [Customizing](../README.md#customizing) for that and the simpler options, like using your app's layout.

To use one of these examples:

1. Copy the file into the same place under `app/views` in your app.
2. Use your own layout, since the engine's layout doesn't load Tailwind (`config.layout = "application"`).
3. Replace `logo_small.png` and `placeholder.png`, which stand in for your app's images.
4. Delete the `<p>` tags that display `notice` and `alert` if your layout displays them too.
