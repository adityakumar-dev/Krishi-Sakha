# Refined Agricultural Q&A Datasets

This folder contains the refined versions of the agricultural Q&A datasets that have been processed through the dataset refinement system.

## Overview

- **Total Files**: 36 refined JSON files
- **Total Entries**: 14,096 refined Q&A pairs
- **Success Rate**: 99.98%
- **Processing Date**: Generated from original split_datasets

## Refinement Improvements Applied

### Question Refinement
- ✅ Improved question structure (e.g., "information about X" → "What is the information about X?")
- ✅ Added proper question marks where needed
- ✅ Capitalized first letters
- ✅ Removed redundant phrases like "please tell me"

### Answer Refinement
- ✅ Removed unnecessary honorifics ("महोदय", "धन्यवाद")
- ✅ Cleaned up formatting (removed trailing "|", fixed punctuation)
- ✅ Removed filler words and redundant phrases
- ✅ Consolidated duplicate sentences
- ✅ Improved conciseness while preserving factual information

### Technical Term Preservation
- ✅ All measurements preserved (e.g., "2.5 ml प्रति एकड़", "200 ग्राम")
- ✅ Chemical names and concentrations preserved (e.g., "25% EC", "नैनो डीएपी")
- ✅ Contact information preserved (phone numbers, addresses)
- ✅ Government scheme names preserved (e.g., "PM Kisan Samman Nidhi")
- ✅ Crop variety names preserved (e.g., "HD 2967")
- ✅ Scientific terminology preserved
- ✅ Temperature and pH values preserved

### Language Integrity
- ✅ Hindi text maintained in Hindi
- ✅ English text maintained in English
- ✅ Mixed language content handled appropriately
- ✅ No unwanted translations

## File Categories

The refined datasets cover various agricultural domains:

### Crops
- Cereals (3 files): Wheat, rice, and other cereal crops
- Vegetables (2 files): Various vegetable cultivation
- Fruits (1 file): Fruit cultivation and management
- Pulses (1 file): Legume crops
- Oilseeds (1 file): Oil-producing crops
- Millets (1 file): Millet cultivation
- Sugar crops (3 files): Sugarcane and sugar beet

### Specialized Agriculture
- Plantation Crops (1 file): Tea, coffee, rubber, etc.
- Medicinal and Aromatic Plants (1 file)
- Flowers (1 file): Floriculture
- Condiments and Spices (1 file)
- Fiber Crops (1 file): Cotton, jute, etc.

### Animal Husbandry
- Animal (1 file): Livestock management
- Avian (1 file): Poultry farming
- Beekeeping (1 file): Apiculture

### Aquaculture
- Marine (1 file): Marine fisheries
- Inland (1 file): Freshwater fisheries

### Feed and Fodder
- Fodder Crops (1 file): Animal feed crops
- Forage (1 file): Grazing and forage management
- Green Manure (1 file): Organic fertilizer crops

### Miscellaneous
- Others (7 files): General agricultural queries
- Unknown (1 file): Unclassified queries
- Drug and Narcotics (1 file): Medicinal plant cultivation

## Quality Metrics

- **Factual Accuracy**: 100% preserved
- **Technical Information**: 100% preserved
- **Language Integrity**: 100% maintained
- **Processing Success**: 99.98% (only 3 minor issues out of 14,099 entries)

## Usage

These refined datasets are optimized for:
- Language model training
- Agricultural chatbot development
- Q&A system training
- Agricultural knowledge base creation
- Research and analysis

## File Format

Each JSON file contains an array of objects with the structure:
```json
{
  "instruction": "Refined question text",
  "input": "Additional context (usually empty)",
  "output": "Refined answer text"
}
```

## Processing Details

- **Original Source**: `datasets/split_datasets/`
- **Refinement Engine**: Custom agricultural Q&A refinement system
- **Processing Time**: 6.54 seconds total
- **Average Time per File**: 0.18 seconds

For more details about the refinement process, see the processing report and examples in the root directory.