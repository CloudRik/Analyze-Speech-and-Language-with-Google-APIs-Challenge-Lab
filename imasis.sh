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

# User input for API Key (Foolproof method for Video Tutorial)
echo "${YELLOW_TEXT}${BOLD_TEXT}Please enter your Google Cloud API Key below:${RESET_FORMAT}"
read -p "${CYAN_TEXT}${BOLD_TEXT}API Key: ${RESET_FORMAT}" API_KEY_INPUT
export API_KEY="$API_KEY_INPUT"
echo "${GREEN_TEXT}✓ API Key received!${RESET_FORMAT}"
echo

# Locate VM Zone
echo "${MAGENTA_TEXT}${BOLD_TEXT}🚀 Locating VM Instance (lab-vm)...${RESET_FORMAT}"
ZONE=$(gcloud compute instances list --filter="name=lab-vm" --format="value(zone)" 2>/dev/null)
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute instances list --format="value(zone)" | head -n 1)
fi

echo "${CYAN_TEXT}VM Zone identified: ${ZONE}${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}Running tasks inside lab-vm SSH session...${RESET_FORMAT}"

# Pipe execution directly into SSH to force VM shell execution context
gcloud compute ssh lab-vm --zone=$ZONE --quiet -- << EOF
export API_KEY="${API_KEY}"

# TASK 2: Entity Analysis
cat > nl_request.json << 'JSON_EOF'
{
  "document": {
    "type": "PLAIN_TEXT",
    "content": "With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States."
  },
  "encodingType": "UTF8"
}
JSON_EOF

curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=\${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @nl_request.json > nl_response.json

# TASK 3: Speech Analysis
cat > speech_request.json << 'JSON_EOF'
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
  "https://speech.googleapis.com/v1/speech:recognize?key=\${API_KEY}" > speech_response.json

# TASK 4: Sentiment Analysis
cat > sentiment_analysis.py << 'PY_EOF'
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

gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz .
gunzip -f sentiment-samples.tgz
tar -xvf sentiment-samples.tar

python3 sentiment_analysis.py reviews/bladerunner-pos.txt
EOF

print_completion
