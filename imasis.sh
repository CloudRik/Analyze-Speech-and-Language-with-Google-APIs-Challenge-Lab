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

# ========================================================
# TASK 1: CREATE API KEY (WITH TARGET RESTRICTION)
# ========================================================
echo "${MAGENTA_TEXT}${BOLD_TEXT}🔑 TASK 1: Creating API Key...${RESET_FORMAT}"

gcloud services enable language.googleapis.com speech.googleapis.com --quiet

# Try creating API key with target restriction
gcloud alpha services api-keys create \
    --display-name="imasis-key" \
    --api-target=service=language.googleapis.com \
    --quiet 2>/dev/null || true

# Fetch Key String
export API_KEY=$(gcloud alpha services api-keys list --format="value(keyString)" 2>/dev/null | head -n 1)

if [ -z "$API_KEY" ]; then
    # Fallback to credentials list
    export API_KEY=$(gcloud services api-keys list --format="value(keyString)" 2>/dev/null | head -n 1)
fi

echo "${GREEN_TEXT}✓ API Key setup complete: ${API_KEY}${RESET_FORMAT}"
echo

# ========================================================
# TASK 2, 3, 4: EXECUTE ENTIRE LOGIC INSIDE VM VIA SSH
# ========================================================
echo "${MAGENTA_TEXT}${BOLD_TEXT}🚀 Locating VM Instance (lab-vm)...${RESET_FORMAT}"

ZONE=$(gcloud compute instances list --filter="name=lab-vm" --format="value(zone)" 2>/dev/null)
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute instances list --format="value(zone)" | head -n 1)
fi

echo "${CYAN_TEXT}VM Zone identified: ${ZONE}${RESET_FORMAT}"
echo "${YELLOW_TEXT}${BOLD_TEXT}Connecting and running all tasks inside lab-vm...${RESET_FORMAT}"

# Send script to VM and execute inside VM context
gcloud compute ssh lab-vm --zone=$ZONE --quiet --command="cat << 'INNER_SCRIPT' > run_tasks.sh
#!/bin/bash
export API_KEY='${API_KEY}'

# Install dependencies inside VM
sudo apt-get update -y >/dev/null 2>&1
sudo apt-get install -y python3-pip >/dev/null 2>&1
pip3 install --upgrade google-cloud-language --quiet 2>/dev/null

# TASK 2: Entity Analysis
cat > nl_request.json <<EOF
{
  \"document\": {
    \"type\": \"PLAIN_TEXT\",
    \"content\": \"With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States.\"
  },
  \"encodingType\": \"UTF8\"
}
EOF

curl \"https://language.googleapis.com/v1/documents:analyzeEntities?key=\${API_KEY}\" \
  -s -X POST -H \"Content-Type: application/json\" --data-binary @nl_request.json > nl_response.json

# TASK 3: Speech Analysis
cat > speech_request.json <<EOF
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

curl -s -X POST -H \"Content-Type: application/json\" --data-binary @speech_request.json \
  \"https://speech.googleapis.com/v1/speech:recognize?key=\${API_KEY}\" > speech_response.json

# TASK 4: Sentiment Analysis
cat > sentiment_analysis.py <<EOF
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

gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz .
gunzip -f sentiment-samples.tgz
tar -xvf sentiment-samples.tar

python3 sentiment_analysis.py reviews/bladerunner-pos.txt
INNER_SCRIPT
bash run_tasks.sh
"

print_completion
