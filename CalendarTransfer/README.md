## How To Sync Files Between Two Laptops Using Calendar API

#### What Does This CLI Program Do ?

- Sync a file from one laptop to another using calendar file attachment
- Uses a fixed date of Jan-1 2024 to create an event with file attachment

#### Why this program ?

- Work around to sync files programmatically
- Air drop is disabled on one of the laptops
- iCloud drive is disabled on one of the laptops
- USB drive is disabled on one of the laptops
- File sharing is disabled on one of the laptop

#### So how to sync ?

- Since iCloud calendar sync works on both the laptops, use that to sync files

#### Pre-requisites

- Same iCloud account on both the laptops
- Make sure you have a calender by name "files" in iCloud calendar
- Make sure your file is less than 1MB 
  - Using Calendar event file attachment feature
  - Calendar event attachment limit of 1MB
  - FYI-1 : Suited ideally for text files
  - FYI-2 : Better to zip all your text files and use the zip file to upload
- Make sure you have Calendar sync every 1-minute in both the laptops
- Make sure the same binary "CalendarTransfer" is present in both the laptops
  - So that you can 
    - Upload from laptop-1 and download on laptop-2
    - (OR)
    - Upload from laptop-2 and download on laptop-1

#### CLI

- Using XCode build the binary first : Product > Build
- Once the binary is built, it  will generate "CalendarTransfer" binary file

```
find ~/Library/Developer/Xcode/DerivedData -name "CalendarTransfer"
```

> Output

```
/Users/giri/Library/Developer/Xcode/DerivedData/CalendarTransfer-azifhsokjpgolkguovpwghsuasje/Build/Products/Release/CalendarTransfer
```

```
cd /Users/giri/Library/Developer/Xcode/DerivedData/CalendarTransfer-azifhsokjpgolkguovpwghsuasje/Build/Products/Release/
```

> Upload From (Laptop-1)

```
./CalendarTransfer upload ~/git/data/stuff/some_file.pdf
```

> Download On (Laptop-2)

```
./CalendarTransfer download some_file.pdf ~/tmp
```

> Same thing can be done in the reverse way : upload from laptop-2 and download on laptop-1
