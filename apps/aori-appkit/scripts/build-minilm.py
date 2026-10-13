#!/usr/bin/env python3
"""Convert all-MiniLM-L6-v2 to a Core ML sentence embedder.

The source model is sentence-transformers/all-MiniLM-L6-v2.
Its license is Apache-2.0.
This script needs transformers 4.44 and writes a neural-network mlmodel.
Linux can save the spec. Prediction needs macOS.
"""

import json
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "Sources" / "AoriCore" / "Resources"
MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"
LENGTH = 128
SENTENCES = ["I like tea", "tea please", "The cat is orange", "tea, please"]


class MeanPool(torch.nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.encoder = AutoModel.from_pretrained(MODEL_ID, attn_implementation="eager")
        self.register_buffer("position_ids", torch.arange(LENGTH).unsqueeze(0))
        self.register_buffer("token_type_ids", torch.zeros(1, LENGTH, dtype=torch.long))

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        hidden = self.encoder(
            input_ids=input_ids,
            attention_mask=attention_mask,
            position_ids=self.position_ids,
            token_type_ids=self.token_type_ids,
        ).last_hidden_state
        mask = attention_mask.unsqueeze(-1).to(hidden.dtype)
        summed = (hidden * mask).sum(dim=1)
        counts = mask.sum(dim=1).clamp(min=1e-9)
        vector = summed / counts
        norm = torch.sqrt((vector * vector).sum(dim=1, keepdim=True).clamp(min=1e-12))
        return vector / norm


def main() -> None:
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    DEST.mkdir(parents=True, exist_ok=True)
    module = MeanPool().eval()
    encoded = tokenizer(
        SENTENCES,
        padding="max_length",
        truncation=True,
        max_length=LENGTH,
        return_tensors="pt",
    )
    with torch.no_grad():
        reference = module(encoded["input_ids"], encoded["attention_mask"]).numpy()
    ids = torch.zeros(1, LENGTH, dtype=torch.int64)
    mask = torch.ones(1, LENGTH, dtype=torch.int64)
    traced = torch.jit.trace(module, (ids, mask))
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, LENGTH), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, LENGTH), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="neuralnetwork",
    )
    spec = mlmodel.get_spec()
    output = spec.description.output[0].type.multiArrayType
    del output.shape[:]
    output.shape.extend([1, 384])
    out = DEST / "aori-minilm.mlmodel"
    ct.models.MLModel(spec).save(str(out))
    rows = []
    for index, sentence in enumerate(SENTENCES):
        token_ids = encoded["input_ids"][index].tolist()
        token_mask = encoded["attention_mask"][index].tolist()
        kept = [int(token) for token, flag in zip(token_ids, token_mask, strict=True) if flag == 1]
        rows.append({
            "text": sentence,
            "ids": kept,
            "values": [float(item) for item in reference[index]],
        })
    (DEST / "aori-minilm-reference.json").write_text(json.dumps(rows))
    vocab = tokenizer.get_vocab()
    lines = [""] * len(vocab)
    for token, token_id in vocab.items():
        lines[token_id] = token
    (DEST / "aori-minilm-vocab.txt").write_text("\n".join(lines) + "\n")
    print("saved", out)


if __name__ == "__main__":
    main()
