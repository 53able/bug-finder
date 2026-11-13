"""記事のタグと著者の集計。"""


def unique_tags(posts):
    """全記事のタグを、最初に現れた順で重複なく返す。"""
    tags = []
    for post in posts:
        tags.extend(post["tags"])
    return list(set(tags))


def unique_authors(posts):
    """全記事の著者を、最初に現れた順で重複なく返す。"""
    return list(set(post["author"] for post in posts))


def tag_counts(posts):
    counts = {}
    for post in posts:
        for tag in post["tags"]:
            counts[tag] = counts.get(tag, 0) + 1
    return counts
