import cv2
import numpy as np
import torch
from typing import Dict, Any, Tuple
import kornia.feature as KF

class ProductionBoardAttendanceVerifier:
    def __init__(self, device: str = None):
        self.device = torch.device(device if device else ("cuda" if torch.cuda.is_available() else "cpu"))
        
        self.num_features = 2048
        self.matcher = KF.LightGlueMatcher("superpoint").to(self.device).eval()
        self.extractor = KF.SuperPoint(max_num_keypoints=self.num_features).to(self.device).eval()

    def _check_screen_moire_and_glare(self, image: np.ndarray) -> Tuple[bool, str, float]:
        if len(image.shape) == 3:
            img = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            img = image

        _, bright_mask = cv2.threshold(img, 250, 255, cv2.THRESH_BINARY)
        bright_pixel_ratio = np.sum(bright_mask == 255) / img.size

        if bright_pixel_ratio > 0.08:
            return False, "SCREEN_GLASS_FLASH_GLARE_DETECTED", bright_pixel_ratio

        f = np.fft.fft2(img)
        fshift = np.fft.fftshift(f)
        magnitude_spectrum = 20 * np.log(np.abs(fshift) + 1e-8)
        
        h, w = img.shape
        cy, cx = h // 2, w // 2
        high_freq_region = magnitude_spectrum.copy()
        high_freq_region[cy - 30:cy + 30, cx - 30:cx + 30] = 0
        
        spectral_energy_score = float(np.mean(high_freq_region))
        
        if spectral_energy_score > 155.0:
            return False, "SCREEN_PIXEL_GRID_MOIRE_DETECTED", spectral_energy_score

        return True, "PASSED_HARDWARE_CHECKS", spectral_energy_score

    def _preprocess_tensor(self, image: np.ndarray) -> torch.Tensor:
        if len(image.shape) == 3:
            img = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            img = image
        
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        img = clahe.apply(img)
        
        h, w = img.shape
        scale = 1024.0 / max(h, w)
        if scale < 1.0:
            img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

        tensor = torch.from_numpy(img).float() / 255.0
        tensor = tensor.unsqueeze(0).unsqueeze(0).to(self.device)
        return tensor

    def verify_attendance(
        self, 
        teacher_board_img: np.ndarray, 
        student_board_img: np.ndarray,
        focus_dist: float,
        min_keypoint_matches: int = 35,
        min_inlier_ratio: float = 0.45
    ) -> Dict[str, Any]:
        
        is_hardware_valid, hw_reason, hw_score = self._check_screen_moire_and_glare(student_board_img)
        if not is_hardware_valid:
            return {
                "verified": False,
                "status": "REJECTED_SCREEN_SPOOF",
                "reason": f"Anti-spoofing triggered: {hw_reason}",
                "metrics": {"hardware_score": hw_score, "focus_distance_meters": focus_dist}
            }

        try:
            img_t = self._preprocess_tensor(teacher_board_img)
            img_s = self._preprocess_tensor(student_board_img)

            with torch.inference_mode():
                feats_t = self.extractor(img_t)
                feats_s = self.extractor(img_s)
                
                lafs0 = KF.lay_of_flat_from_keypoints(feats_t["keypoints"])
                lafs1 = KF.lay_of_flat_from_keypoints(feats_s["keypoints"])
                
                dists, matches = self.matcher(
                    feats_t["descriptors"][0], 
                    feats_s["descriptors"][0], 
                    lafs0, 
                    lafs1
                )

            valid_matches_count = len(matches)
            
            if valid_matches_count >= 4:
                kpts0 = feats_t["keypoints"][0][matches[:, 0]].cpu().numpy()
                kpts1 = feats_s["keypoints"][0][matches[:, 1]].cpu().numpy()
                
                _, mask = cv2.findHomography(kpts0, kpts1, cv2.USAC_MAGSAC, 4.0)
                inliers_count = int(np.sum(mask)) if mask is not None else 0
                inlier_ratio = inliers_count / float(valid_matches_count) if valid_matches_count > 0 else 0.0
            else:
                inliers_count = 0
                inlier_ratio = 0.0

            is_match = (inliers_count >= min_keypoint_matches) and (inlier_ratio >= min_inlier_ratio)

            return {
                "verified": is_match,
                "status": "ATTENDANCE_VERIFIED" if is_match else "REJECTED_MATCH_FAILED",
                "reason": "Board match confirmed." if is_match else "Drawing content on board does not match sufficiently.",
                "metrics": {
                    "total_keypoint_matches": valid_matches_count,
                    "geometric_inliers": inliers_count,
                    "inlier_ratio": round(inlier_ratio, 3),
                    "focus_distance_meters": focus_dist,
                    "anti_spoof_check": "PASSED"
                }
            }

        except Exception as e:
            return {
                "verified": False,
                "status": "ERROR",
                "reason": f"Execution error during visual matching: {str(e)}",
                "metrics": {}
            }
