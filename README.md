# Pinboard Notes by Navya
A modern, desktop-focused note-taking application designed with a unique pinboard interface for intuitive and visual organization of notes, images, and folders. This project is developed as part of the CRUx Inductions process.

## Table of Contents

1.  [Overview](#overview)
2.  [Features](#features)
    *   [Core Functionality](#core-functionality)
    *   [User Interface & Experience](#user-interface--experience)
    *   [Data Management](#data-management)
3.  [Tech Stack](#tech-stack)
4.  [Usage](#usage)
5.  [Future Work](#future-work)
6.  [Remarks](#remarks)

## Overview

The Pinboard Notes App offers a dynamic and interactive way to manage your thoughts, ideas, and visual inspirations. Unlike traditional linear note-taking apps, this application provides a freeform canvas where users can:
*   Create text notes, add images, and organize them into folders.
*   Freely move and arrange items on a large board.
*   Experience smooth animations and a visually pleasing interface.

The primary goal is to create an engaging and fun user experience while providing robust note-taking capabilities.

## Features

### Core Functionality

*   **Board Interface:**
    *   A central 'birds-eye' view where all items are displayed.
    *   Items (notes, images, folders) can be dragged and dropped anywhere on the board.
    *   Support for selecting multiple items to move them together as a group.
      <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/individual_drag.gif height=450 width=700>


      <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/group_drag.gif height=450 width=700>
      
*   **Item Types:**
    *   **Notes:**
        *   Create text-based notes with customizable background colors.
        *   Double-tap a note to open a full-screen editor.
        *   Simple text editing capabilities with a save function.
          
     <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/note_opening_closing.gif height=450 width=700>
     
    *   **Images:**
        *   Add images to the board from local storage (via image picker).
        *   Images can be moved and resized directly on the board using drag handles.
        *   Clicking on an image (when not resizing) currently performs no action.
          
     <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/add_new_img.gif height=450 width=700>
     
    *   **Folders:**
        *   Organize notes and images within folders (folders cannot contain other folders).
        *   Create folders via a "New" button or by dragging selected items to the "New" button area.
        *   Double-tap a closed folder's name to rename it.
        *   Double-tap a closed folder to open it, revealing its contents in a "cards on a table" layout.
        *   Double-tap an open folder to close it, tucking items back in.
        *   Open folders display a bounding box around their contents and the folder icon itself.
        *   Drag items into/out of open folders or onto closed folders to manage their contents.
        *   Only one folder can be open at a time; opening another folder closes the currently open one.
          
      <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/create_new_folder.gif height=450 width=700>



      <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/add_remove_from_folder.gif height=450 width=700>
      
*   **"New" Button:**
    *   A persistent button to create new Notes, Images, or Folders.
    *   Acts as a drop target: drag multiple selected notes/images onto it to create a new folder containing them.
    *   Can also be used to clear the selection in case multiple items are selected together.

### User Interface & Experience

*   **Desktop First:** Designed and optimized for desktop platforms (built and tested primarily on macos).
*   **Animations:**
    *   **Note Opening/Closing:** Selected note smoothly expands to fill the screen while other board items animate away. They return when the note editor is closed.
    *   **Folder Opening/Closing:** Contents animate out from the folder icon to a "cards on a table" layout and animate back in when the folder is closed.
    *   **Item Evasion:** Top-level items animate to move out of the way if an opening folder's content area would overlap them.
    *   Smooth transitions for drag-and-drop and item selection.
*   **Themeing:**
    *   Supports **Light and Dark themes**.
    *   A toggle button in the AppBar allows users to switch between themes.
    *   Theme preference is persisted across app sessions.
      
   <img src=https://github.com/navgarg/Loose-Files/blob/master/notes_ss/light_dark_theme.gif height=450 width=700>
   
*   **Visual Feedback:**
    *   Clear visual cues for selected items.
    *   Hover effects and drag feedback for items.
    *   Bounding box for open folders.

### Data Management

*   **Data Persistence:** All board items (notes, images, folders, positions, content, etc.) are saved  using Cloud Firestore (per user). The board state is restored when the app is reopened.
*   **User Authentication:**
    *   Google Sign-In for user authentication via Firebase Authentication.
    *   Each user has their own dedicated board.
*   **State Management:**
    *   Utilizes Riverpod for robust and scalable state management.

## Tech Stack

*   **Framework:** Flutter
*   **Language:** Dart
*   **Database:** Cloud Firestore (Firebase)
*   **Authentication:** Firebase Authentication (Google Sign-In)
*   **State Management:** Riverpod
*   **Key Packages:**
    *   `flutter_riverpod`
    *   `firebase_core`, `firebase_auth`, `cloud_firestore`
    *   `google_sign_in`
    *   `uuid` (for generating unique item IDs)
    *   `flutter_colorpicker` (for note color selection)
    *   `shared_preferences` (for theme persistence)
      
 ## Usage

1.  Upon launching the app, you will be prompted to sign in with your Google account.
2.  After successful authentication, you will land on your personal pinboard.
3.  Use the **"+ New"** button (bottom right FAB) to add new notes, images, or folders.
4.  **Interact with items:**
    *   **Drag** items to reposition them.
    *   **Single-tap** a note or image to select/deselect it.
    *   **Single-tap** a closed folder to select/deselect it.
    *   **Double-tap** a note to open its editor.
    *   **Double-tap** a closed folder to open/close it, revealing/hiding its contents.
    *   **Double-tap a closed folder's name** to edit its name. Press Enter to save.
    *   **Resize images** using their corner drag handles.
5.  Use the **theme toggle icon** in the AppBar to switch between light and dark modes.
6.  Use the **logout icon** in the AppBar to sign out.

## Future Work

* More sophisticated item evasion logic (e.g., radial push, considering multiple overlaps).
* Cloud save for images (currently URLs are saved, but actual image binary upload could be a feature).
* More advanced text editor features for notes.
* Search/filter functionality for board items.
* Customizable grid snapping or alignment guides.
* Performance optimizations for very large boards.


## Remarks
I want to thank CRUx for giving me the opportunity to work on this project. Working on this project significantly deepened my understanding of building dynamic UIs in Flutter. Coordinating simultaneous animations for a fluid user experience proved a key challenge, emphasizing the importance of careful state management and event timing.
