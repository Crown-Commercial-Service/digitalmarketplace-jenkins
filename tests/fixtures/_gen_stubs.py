#!/bin/env python

def tree_paths(tree, prefix=""):
    if isinstance(tree, dict):
        return {
            k: tree_paths(v, "{}__{}__".format(prefix, k))
            for k, v in tree.items()
        }
    elif isinstance(tree, list):
        return [
            tree_paths(v, "{}__[{}]__".format(prefix, n))
            for n, v in enumerate(tree)
        ]
    else:
        return prefix

if __name__ == "__main__":
    import yaml
    import sys

    yaml.dump(
        tree_paths(yaml.load(sys.stdin)),
        stream=sys.stdout,
        default_flow_style=False,
    )
