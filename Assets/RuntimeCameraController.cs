using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RuntimeCameraController : MonoBehaviour
{
    public float moveSpeed = 50.0f; // ī�޶� �̵� �ӵ�
    public float rotationSpeed = 500.0f; // ī�޶� ȸ�� �ӵ�
    public float fastMoveSpeed = 100.0f; // ShiftŰ�� ������ �̵��� �� �ӵ�

    private void Update()
    {
        // �̵�
        float moveDirectionX = Input.GetAxis("Horizontal"); // A, D Ű
        float moveDirectionZ = Input.GetAxis("Vertical");   // W, S Ű

        Vector3 move = new Vector3(moveDirectionX, 0, moveDirectionZ);
        if (Input.GetKey(KeyCode.LeftShift)) // ShiftŰ�� ������ ������ �̵�
        {
            transform.Translate(move * fastMoveSpeed * Time.deltaTime);
        }
        else
        {
            transform.Translate(move * moveSpeed * Time.deltaTime);
        }

        // ��/�Ʒ� �̵� (Q, E Ű)
        if (Input.GetKey(KeyCode.E))
        {
            transform.Translate(Vector3.up * moveSpeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.Q))
        {
            transform.Translate(Vector3.down * moveSpeed * Time.deltaTime);
        }

        // ���콺 �Է����� ȸ��
        if (Input.GetMouseButton(1)) // ��Ŭ�� �� ȸ�� ����
        {
            float mouseX = Input.GetAxis("Mouse X");
            float mouseY = Input.GetAxis("Mouse Y");

            // ī�޶� ȸ�� (X���� ����, Y�ุ ȸ��)
            transform.Rotate(Vector3.up, mouseX * rotationSpeed * Time.deltaTime, Space.World);
            transform.Rotate(Vector3.right, -mouseY * rotationSpeed * Time.deltaTime, Space.Self);
        }
    }
}
