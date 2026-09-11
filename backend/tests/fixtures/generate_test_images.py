"""Generate simple face-like JPEG fixtures for integration testing."""

from pathlib import Path

import cv2
import numpy as np


FIXTURES_DIR = Path(__file__).resolve().parent


def _draw_face(image, center):
    x, y = center
    cv2.ellipse(image, (x, y - 20), (70, 90), 0, 0, 360, (220, 180, 150), -1)
    cv2.circle(image, (x - 25, y - 35), 8, (40, 40, 40), -1)
    cv2.circle(image, (x + 25, y - 35), 8, (40, 40, 40), -1)
    cv2.ellipse(image, (x, y + 10), (25, 12), 0, 0, 180, (80, 40, 40), 2)


def _create_face_image(seed, filename):
    rng = np.random.default_rng(seed)
    image = np.full((480, 640, 3), (240, 240, 240), dtype=np.uint8)
    _draw_face(image, (320, 240))

    noise = rng.integers(-8, 9, size=image.shape, dtype=np.int16)
    image = np.clip(image.astype(np.int16) + noise, 0, 255).astype(np.uint8)

    output_path = FIXTURES_DIR / filename
    cv2.imwrite(str(output_path), image)
    print(f'Created {output_path}')


if __name__ == '__main__':
    _create_face_image(42, 'teacher_shape.jpeg')
    _create_face_image(42, 'student_photo.jpeg')
    print('Use different seeds for mismatch testing by editing this script.')
