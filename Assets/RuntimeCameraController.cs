using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RuntimeCameraController : MonoBehaviour
{
    public float moveSpeed = 50.0f; // 카메라 이동 속도
    public float rotationSpeed = 500.0f; // 카메라 회전 속도
    public float fastMoveSpeed = 100.0f; // Shift키로 빠르게 이동할 때 속도

    private void Update()
    {
        // 이동
        float moveDirectionX = Input.GetAxis("Horizontal"); // A, D 키
        float moveDirectionZ = Input.GetAxis("Vertical");   // W, S 키

        Vector3 move = new Vector3(moveDirectionX, 0, moveDirectionZ);
        if (Input.GetKey(KeyCode.LeftShift)) // Shift키를 누르면 빠르게 이동
        {
            transform.Translate(move * fastMoveSpeed * Time.deltaTime);
        }
        else
        {
            transform.Translate(move * moveSpeed * Time.deltaTime);
        }

        // 위/아래 이동 (Q, E 키)
        if (Input.GetKey(KeyCode.E))
        {
            transform.Translate(Vector3.up * moveSpeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.Q))
        {
            transform.Translate(Vector3.down * moveSpeed * Time.deltaTime);
        }

        // 마우스 입력으로 회전
        if (Input.GetMouseButton(1)) // 우클릭 시 회전 가능
        {
            float mouseX = Input.GetAxis("Mouse X");
            float mouseY = Input.GetAxis("Mouse Y");

            // 카메라 회전 (X축은 고정, Y축만 회전)
            transform.Rotate(Vector3.up, mouseX * rotationSpeed * Time.deltaTime, Space.World);
            transform.Rotate(Vector3.right, -mouseY * rotationSpeed * Time.deltaTime, Space.Self);
        }
    }
}
