"""Sample assets for Dagster ECS deployment based on Dagster tutorial."""

import re
from collections import Counter

import pandas as pd
import requests
from dagster import AssetExecutionContext, asset

# Configuration
REPOSITORY_NAME = "main"
HTTP_OK_STATUS = 200


@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def hackernews_top_story_ids() -> list[int]:
    """Get top story IDs from Hacker News API.

    This asset fetches the current top stories from Hacker News.
    """
    # Fetch top stories from Hacker News API
    response = requests.get("https://hacker-news.firebaseio.com/v0/topstories.json")
    response.raise_for_status()

    # Return top 10 story IDs for demo purposes
    return response.json()[:10]


@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def hackernews_top_stories(
    context: AssetExecutionContext, hackernews_top_story_ids: list[int]
) -> pd.DataFrame:
    """Get detailed information for top stories.

    This asset fetches detailed story information for each story ID.
    """
    stories = []

    for story_id in hackernews_top_story_ids:
        story_response = requests.get(
            f"https://hacker-news.firebaseio.com/v0/item/{story_id}.json"
        )
        if story_response.status_code == HTTP_OK_STATUS:
            story = story_response.json()
            if story and story.get("type") == "story":
                stories.append(
                    {
                        "id": story.get("id"),
                        "title": story.get("title", "")[:100],  # Truncate for display
                        "url": story.get("url", ""),
                        "score": story.get("score", 0),
                        "time": story.get("time", 0),
                        "descendants": story.get("descendants", 0),  # comment count
                    }
                )

    df = pd.DataFrame(stories)
    context.log.info(f"Fetched {len(df)} stories")
    return df


@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def most_frequent_words(
    context: AssetExecutionContext, hackernews_top_stories: pd.DataFrame
) -> pd.DataFrame:
    """Find the most frequent words in story titles.

    This asset analyzes the titles to find common words.
    """

    # Extract all words from titles
    all_titles = " ".join(hackernews_top_stories["title"].fillna(""))

    # Simple word extraction (letters only, lowercase)
    words = re.findall(r"\b[a-zA-Z]{3,}\b", all_titles.lower())

    # Remove common stop words
    stop_words = {
        "the",
        "and",
        "for",
        "are",
        "but",
        "not",
        "you",
        "all",
        "can",
        "had",
        "her",
        "was",
        "one",
        "our",
        "out",
        "day",
        "get",
        "has",
        "him",
        "his",
        "how",
        "its",
        "may",
        "new",
        "now",
        "old",
        "see",
        "two",
        "who",
        "boy",
        "did",
        "men",
        "oil",
        "run",
        "she",
        "too",
        "use",
        "way",
        "win",
        "yes",
    }

    filtered_words = [word for word in words if word not in stop_words]

    # Count word frequencies
    word_counts = Counter(filtered_words)

    # Create DataFrame with top 20 words
    top_words = word_counts.most_common(20)
    df = pd.DataFrame(top_words, columns=["word", "count"])

    context.log.info(f"Found {len(word_counts)} unique words, showing top {len(df)}")
    return df


# Export all assets
sample_assets = [
    hackernews_top_story_ids,
    hackernews_top_stories,
    most_frequent_words,
]
