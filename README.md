## Overview

This is a Lua script for Assetto Corsa that allows you to use the [Ratings Manager](https://github.com/ReneValjaots/Ac.Ratings) in-game.

## Installation
1. Download the latest `ratings_manager_lua.zip` from the Releases page.
2. Extract the zip file.
3. Copy the entire `apps` folder from the zip into your **Assetto Corsa root folder**. Example:

  ```
  C:\Program Files (x86)\Steam\steamapps\common\assettocorsa
  ```

## Configuration

The script uses a local config.ini file placed in the same folder as the Lua script. Example:

```ini
[Settings]
install_path=C:/path/to/your/Ratings Manager
rating_scale=10
```

You can set the install path through the **Settings** tab in the in-game UI.\
Make sure to select the main **Ratings Manager** folder where `Ratings Manager.exe` is installed. Example:

```
C:\Users\guest\Desktop\Ratings Manager
```

The script automatically fetches the correct `rating_scale` on startup.
