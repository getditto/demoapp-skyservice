# SkyService

Inflight Meal Order without internet

This passenger meal order demo showcases a set of premade user interface components that can quickly help your airline deploy a world class passenger and crew ordering experience that does not require any internet connectivity.

Powered by [Ditto](https://ditto.live/).


- [Video Demo](https://www.youtube.com/watch?v=XuUpQ_Oabg0)
- [iOS Download (Crew App)](https://apps.apple.com/us/app/skyservice-crew/id1578101315)
- [iOS Download (Passenger App)](https://apps.apple.com/us/app/skyservice-ditto/id1578101340)
- [Android Download (Passenger App)](https://play.google.com/store/apps/details?id=live.dittolive.skyservice)


## Features

#### Real-time Meal Item Editing
* Set menu item name, details, price and more, syncing to passenger and crew devices in real-time

#### Customizable Options

* Add multiple choice or single choice options to items such as "add milk", "sauce on side" etc...

#### Category Control
* Categorize and reorder menu items into sections like "Appetizers", "Main Course", and "Desserts"

#### Manage Passenger Information
* Change seats, name, and description during the flight
* Add notes to each passenger. (example: 'Allergic to peanuts')

#### Order and Inventory Management
* Sync accurate inventory between galleys
* See all active orders and status changes in real-time
* Edit, add, and delete items on the fly

#### Amplify Crew Chat

* Send text messages to other crew members
* Invite ground staff for additional communication


## How to build the apps

### iOS

1. Run `cp .env.template .env` at the root directory
1. Edit `.env` to add environment variables
1. Open the app project on Xcode and clean (<kbd>Command</kbd> + <kbd>Shift</kbd> + <kbd>K</kbd>)
1. Build (<kbd>Command</kbd> + <kbd>B</kbd>)
    - This will generate `Env.swift`

### Android

1. Open `/Android/gradle.properties` and add environment variables
1. Build the app normally


## License

MIT
