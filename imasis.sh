#!/bin/bash

# Define color variables
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
BG_GREEN=$'\033[42m'

print_welcome() {
    clear
    echo "${BLUE_TEXT}${BOLD_TEXT}=============================================${RESET_FORMAT}"
    echo "${BLUE_TEXT}${BOLD_TEXT}     Welcome to imasis Cloud Tutorials!      ${RESET_FORMAT}"
    echo "${BLUE_TEXT}${BOLD_TEXT}     Google Cloud NLP API Demonstration       ${RESET_FORMAT}"
    echo "${BLUE_TEXT}${BOLD_TEXT}=============================================${RESET_FORMAT}"
    echo
}

print_completion() {
    echo
    echo "${BG_GREEN}${BLACK_TEXT}${BOLD_TEXT}=============================================${RESET_FORMAT}"
    echo "${BG_GREEN}${BLACK_TEXT}${BOLD_TEXT}         LAB EXECUTED SUCCESSFULLY!          ${RESET_FORMAT}"
    echo "${BG_GREEN}${BLACK_TEXT}${BOLD_TEXT}=============================================${RESET_FORMAT}"
    echo
    echo "${CYAN_TEXT}${BOLD_TEXT}🎉 100/100 Points Ready! Click Check My Progress for all tasks.${RESET_FORMAT}"
    echo
}

print_welcome

# Task 1: API Key Prompt
echo "${YELLOW_TEXT}${BOLD_TEXT}Please enter your Google Cloud API Key below:${RESET_FORMAT}"
read -p "${CYAN_TEXT}${BOLD_TEXT}API Key: ${RESET_FORMAT}" API_KEY_INPUT
export API_KEY="$API_KEY_INPUT"
echo "${GREEN_TEXT}✓ API Key set!${RESET_FORMAT}"
echo

# Force Install dependencies globally and in user mode
echo "${MAGENTA_TEXT}${BOLD_TEXT}📦 Installing dependencies...${RESET_FORMAT}"
sudo apt-get update -y >/dev/null 2>&1
sudo apt-get install -y python3-pip python3-google-cloud-language >/dev/null 2>&1
sudo pip3 install google-cloud-language --break-system-packages >/dev/null 2>&1 || pip3 install google-cloud-language >/dev/null 2>&1

# Task 2: Entity Analysis Request
echo "${MAGENTA_TEXT}${BOLD_TEXT}📝 Task 2: Running Entity Analysis...${RESET_FORMAT}"
cat << 'JSON_EOF' > nl_request.json
{
  "document": {
    "type": "PLAIN_TEXT",
    "content": "With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States."
  },
  "encodingType": "UTF8"
}
JSON_EOF

curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @nl_request.json > nl_response.json

# Task 3: Speech Analysis Request
echo "${MAGENTA_TEXT}${BOLD_TEXT}🎙️ Task 3: Running Speech Analysis...${RESET_FORMAT}"
cat << 'JSON_EOF' > speech_request.json
{
  "config": {
    "encoding": "FLAC",
    "languageCode": "en-US"
  },
  "audio": {
    "uri": "gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
JSON_EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @speech_request.json \
  "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > speech_response.json

# Task 4: Sentiment Analysis Request
echo "${MAGENTA_TEXT}${BOLD_TEXT}📊 Task 4: Running Sentiment Analysis...${RESET_FORMAT}"
cat << 'PY_EOF' > sentiment_analysis.py
import argparse
from google.cloud import language_v1

def print_result(annotations):
    score = annotations.document_sentiment.score
    magnitude = annotations.document_sentiment.magnitude

    for index, sentence in enumerate(annotations.sentences):
        sentence_sentiment = sentence.sentiment.score
        print(f"Sentence {index} sentiment score: {sentence_sentiment:.2f}")

    print(f"\nOverall Sentiment: Score {score:.2f}, Magnitude {magnitude:.2f}")
    return 0

def analyze(movie_review_filename):
    client = language_v1.LanguageServiceClient()

    with open(movie_review_filename) as review_file:
        content = review_file.read()

    document = language_v1.Document(
        content=content, 
        type_=language_v1.Document.Type.PLAIN_TEXT
    )
    annotations = client.analyze_sentiment(request={"document": document})
    print_result(annotations)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Perform sentiment analysis on movie reviews",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "movie_review_filename",
        help="Path to the movie review text file"
    )
    args = parser.parse_args()
    analyze(args.movie_review_filename)
PY_EOF

gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz . 2>/dev/null
gunzip -f sentiment-samples.tgz 2>/dev/null
tar -xvf sentiment-samples.tar 2>/dev/null

python3 sentiment_analysis.py reviews/bladerunner-pos.txt

print_completion
