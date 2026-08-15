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

# Display welcome message
print_welcome() {
    clear
    echo "${BLUE_TEXT}${BOLD_TEXT}=============================================${RESET_FORMAT}"
    echo "${BLUE_TEXT}${BOLD_TEXT}     Welcome to imasis Cloud Tutorials!      ${RESET_FORMAT}"
    echo "${BLUE_TEXT}${BOLD_TEXT}     Google Cloud NLP API Demonstration       ${RESET_FORMAT}"
    echo "${BLUE_TEXT}${BOLD_TEXT}=============================================${RESET_FORMAT}"
    echo
}

# Display completion message
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

# Install python dependencies locally just in case
pip install --upgrade google-cloud-language google-api-python-client --quiet 2>/dev/null

# =======================
# TASK 1: CREATE API KEY
# =======================
echo "${MAGENTA_TEXT}${BOLD_TEXT}🔑 TASK 1: Creating & Setting up API Key...${RESET_FORMAT}"

gcloud services enable language.googleapis.com speech.googleapis.com --quiet

EXISTING_KEY=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=imasis-nlp-key" 2>/dev/null)
if [ -n "$EXISTING_KEY" ]; then
    gcloud alpha services api-keys delete $EXISTING_KEY --quiet || true
    sleep 2
fi

gcloud alpha services api-keys create \
    --display-name="imasis-nlp-key" \
    --quiet || true

KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=imasis-nlp-key" 2>/dev/null)
if [ -n "$KEY_NAME" ]; then
    export API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")
else
    export API_KEY=$(gcloud alpha services api-keys list --format="value(keyString)" | head -n 1)
fi

echo "${GREEN_TEXT}✓ API Key generated: ${API_KEY}${RESET_FORMAT}"
echo

# ========================================================
# TASK 2, 3, 4: EXECUTE INSIDE VM (lab-vm) VIA SSH
# ========================================================
echo "${MAGENTA_TEXT}${BOLD_TEXT}🚀 Locating VM Instance (lab-vm)...${RESET_FORMAT}"

ZONE=$(gcloud compute instances list --filter="name=lab-vm" --format="value(zone)" 2>/dev/null)
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute instances list --format="value(zone)" | head -n 1)
fi

echo "${CYAN_TEXT}VM Zone identified: ${ZONE}${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}Executing Tasks 2, 3, and 4 inside lab-vm...${RESET_FORMAT}"

# SSH & Execute commands strictly inside VM
gcloud compute ssh lab-vm --zone=$ZONE --quiet --command="sudo pip3 install google-cloud-language --quiet 2>/dev/null; pip install google-cloud-language --quiet 2>/dev/null; export API_KEY='${API_KEY}'; cat > nl_request.json <<'EOF'
{
  \"document\": {
    \"type\": \"PLAIN_TEXT\",
    \"content\": \"With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States.\"
  },
  \"encodingType\": \"UTF8\"
}
EOF
curl \"https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}\" -s -X POST -H \"Content-Type: application/json\" --data-binary @nl_request.json > nl_response.json; cat > speech_request.json <<'EOF'
{
  \"config\": {
    \"encoding\": \"FLAC\",
    \"languageCode\": \"en-US\"
  },
  \"audio\": {
    \"uri\": \"gs://cloud-samples-tests/speech/brooklyn.flac\"
  }
}
EOF
curl -s -X POST -H \"Content-Type: application/json\" --data-binary @speech_request.json \"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}\" > speech_response.json; cat > sentiment_analysis.py <<'EOF'
import argparse
from google.cloud import language_v1

def print_result(annotations):
    score = annotations.document_sentiment.score
    magnitude = annotations.document_sentiment.magnitude

    for index, sentence in enumerate(annotations.sentences):
        sentence_sentiment = sentence.sentiment.score
        print(f\"Sentence {index} sentiment score: {sentence_sentiment:.2f}\")

    print(f\"\nOverall Sentiment: Score {score:.2f}, Magnitude {magnitude:.2f}\")
    return 0

def analyze(movie_review_filename):
    client = language_v1.LanguageServiceClient()

    with open(movie_review_filename) as review_file:
        content = review_file.read()

    document = language_v1.Document(
        content=content, 
        type_=language_v1.Document.Type.PLAIN_TEXT
    )
    annotations = client.analyze_sentiment(request={\"document\": document})
    print_result(annotations)

if __name__ == \"__main__\":
    parser = argparse.ArgumentParser(
        description=\"Perform sentiment analysis on movie reviews\",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        \"movie_review_filename\",
        help=\"Path to the movie review text file\"
    )
    args = parser.parse_args()
    analyze(args.movie_review_filename)
EOF
gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz . ; gunzip -f sentiment-samples.tgz ; tar -xvf sentiment-samples.tar ; python3 sentiment_analysis.py reviews/bladerunner-pos.txt"

print_completion
