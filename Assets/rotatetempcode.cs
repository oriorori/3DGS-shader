using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class rotatetempcode : MonoBehaviour
{
    [SerializeField]
    private List<GameObject> list_GS_Pivot = new List<GameObject>();

    [SerializeField]
    private float rotSpeed = 100.0f;

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        for (int i = 0; i < list_GS_Pivot.Count; i++) 
        {
            list_GS_Pivot[i].transform.RotateAround(list_GS_Pivot[i].transform.position, Vector3.up, rotSpeed * Time.deltaTime);
        }

    }
}
